// Copyright (C) 2020 Centrifuge
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.15 <0.6.0;
pragma experimental ABIEncoderV2;

import "./fixed_point.sol";

import "tinlake-auth/auth.sol";
import "tinlake-math/interest.sol";

interface NAVFeedLike {
    function calcUpdateNAV() external returns (uint);
    function approximatedNAV() external view returns (uint);
}

interface TrancheLike {
    function tokenSupply() external returns (uint);
}

contract Assessor is Auth, FixedPoint, Interest  {
    // senior ratio from the last epoch executed
    Fixed27        public seniorRatio;
    uint           public seniorDebt_;
    uint           public seniorBalance_;

    // interest rate per second for senior tranche
    Fixed27         public seniorInterestRate;
    uint            public lastUpdateSeniorInterest;

    Fixed27         public maxSeniorRatio;
    Fixed27         public minSeniorRatio;

    uint            public maxReserve;

    TrancheLike     public seniorTranche;
    TrancheLike     public juniorTranche;
    NAVFeedLike     public navFeed;

    constructor() public {
        wards[msg.sender] = 1;
        seniorInterestRate.value = ONE;
        // todo intialize lastUpdateSeniorInterest the first time seniorDebt changes from 0 to positive
        // otherwise interest calculation would be wrong
        lastUpdateSeniorInterest = block.timestamp;
        seniorRatio.value = 0;
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "navFeed") {
            navFeed = NAVFeedLike(addr);
        } else if (contractName == "seniorTranche") {
            seniorTranche = TrancheLike(addr);
        } else if (contractName == "juniorTranche") {
            juniorTranche = TrancheLike(addr);
        } else revert();
    }

    function file(bytes32 name, uint value) public auth {
        if(name == "seniorInterestRate") {
            seniorInterestRate = Fixed27(value);
        }
        else if (name == "maxReserve") {maxReserve = value;}
        else if (name == "maxSeniorRatio") {
            require(value > minSeniorRatio.value, "value-too-small");
            maxSeniorRatio = Fixed27(value);
        }
        else if (name == "minSeniorRatio") {
            require(value < maxSeniorRatio.value, "value-too-big");
            minSeniorRatio = Fixed27(value);
        }
        else {revert("unknown-variable");}
    }

    function _rebalance(uint seniorAsset_, uint seniorRatio_) internal {
        // re-balancing according to new ratio
        // we use the approximated NAV here because during the submission period
        // new loans might have been repaid in the meanwhile which are not considered in the epochNAV
        seniorDebt_ = rmul(navFeed.approximatedNAV(), seniorRatio_);
        seniorBalance_ = safeSub(seniorAsset_, seniorDebt_);
    }

    function updateSeniorAsset(uint seniorRatio_, uint seniorSupply, uint seniorRedeem) external auth {
        dripSeniorDebt();
        uint seniorAsset = safeSub(safeAdd(safeAdd(seniorDebt_, seniorBalance_),seniorSupply), seniorRedeem);
        _rebalance(safeAdd(seniorDebt_, seniorBalance_), seniorRatio_);
        seniorRatio  = Fixed27(seniorRatio_);
    }

    function seniorRatioBounds() public view returns (uint minSeniorRatio_, uint maxSeniorRatio_) {
        return (minSeniorRatio.value, maxSeniorRatio.value);
    }

    function calcUpdateNAV() external returns (uint) {
         return navFeed.calcUpdateNAV();
    }

    function calcSeniorTokenPrice(uint epochNAV, uint epochReserve) external returns(uint) {
        if (epochNAV == 0 && epochReserve == 0) {
            // initial token price at start 1.00
            return ONE;
        }

        uint totalAssets = safeAdd(epochNAV, epochReserve);
        uint seniorAssetValue = safeAdd(seniorBalance_, seniorDebt_);
        if(totalAssets < seniorAssetValue) {
            seniorAssetValue = totalAssets;
        }

        return rdiv(seniorAssetValue, seniorTranche.tokenSupply());
    }

    function calcJuniorTokenPrice(uint epochNAV, uint epochReserve) external returns(uint) {
        if (epochNAV == 0 && epochReserve == 0) {
            // initial token price at start 1.00
            return ONE;
        }
        uint totalAssets = safeAdd(epochNAV, epochReserve);
        uint seniorAssetValue = safeAdd(seniorBalance_, seniorDebt_);
        if(totalAssets < seniorAssetValue) {
            return 0;
        }

        return rdiv(safeSub(totalAssets, seniorAssetValue), juniorTranche.tokenSupply());
    }

    function repaymentUpdate(uint currencyAmount) public auth {
        dripSeniorDebt();

        uint decAmount = rmul(currencyAmount, seniorRatio.value);
        seniorBalance_ = safeAdd(seniorBalance_, decAmount);
        // seniorDebt needs to be decreased for loan repayments
        if (seniorDebt_ < decAmount) {
            seniorDebt_ = 0;
            return;
        }
        seniorDebt_ = safeSub(seniorDebt_, decAmount);

    }

    function borrowUpdate(uint currencyAmount) public auth {
        dripSeniorDebt();

        uint incAmount = rmul(currencyAmount, seniorRatio.value);
        // seniorDebt needs to be increased for loan borrows
        seniorDebt_ = safeAdd(seniorDebt_, incAmount);

        if(seniorBalance_ < incAmount) {
            seniorBalance_ = 0;
            return;
        }
        seniorBalance_ = safeSub(seniorBalance_, incAmount);
    }

    function dripSeniorDebt() public returns (uint) {
        uint newSeniorDebt = seniorDebt();

        if (newSeniorDebt > seniorDebt_) {
            seniorDebt_ = newSeniorDebt;
            lastUpdateSeniorInterest = block.timestamp;
        }
        return seniorDebt_;
    }

    function seniorDebt() public view returns (uint) {
        if (now >= lastUpdateSeniorInterest) {
            return chargeInterest(seniorDebt_, seniorInterestRate.value, lastUpdateSeniorInterest);
        }
        return seniorDebt_;
    }

    function increaseSeniorAsset(uint currencyAmount, uint newSeniorRatio) public auth {
        dripSeniorDebt();

        uint seniorAsset = safeAdd(safeAdd(seniorDebt_, seniorBalance_), currencyAmount);
        // the seniorDebtRatio defines the seniorDebt and seniorBalance
        // split for the increased amount
        _rebalance(seniorAsset, newSeniorRatio);
    }


    function decreaseSeniorAsset(uint currencyAmount, uint newSeniorRatio) public auth {
        dripSeniorDebt();

        uint seniorAsset = safeSub(safeAdd(seniorDebt_, seniorBalance_), currencyAmount);
        // the seniorDebtRatio defines the seniorDebt and seniorBalance
        // split for the increased amount
        _rebalance(seniorAsset, newSeniorRatio);
    }

    function seniorBalance() public returns (uint) {
        return seniorBalance_;
    }
}
