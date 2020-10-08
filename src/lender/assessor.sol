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

import "./../fixed_point.sol";
import "tinlake-auth/auth.sol";
import "tinlake-math/interest.sol";

interface NAVFeedLike {
    function calcUpdateNAV() external returns (uint);
    function approximatedNAV() external view returns (uint);
    function currentNAV() external view returns(uint);
}

interface TrancheLike {
    function tokenSupply() external view returns (uint);
}

interface ReserveLike {
    function totalBalance() external view returns(uint);
}

contract Assessor is Auth, FixedPoint, Interest {
    // senior ratio from the last epoch executed
    Fixed27        public seniorRatio;

    // the seniorAsset value is stored in two variables
    // seniorDebt is the interest bearing amount for senior
    uint           public seniorDebt_;
    // senior balance is the rest which is not used as interest
    // bearing amount
    uint           public seniorBalance_;

    // interest rate per second for senior tranche
    Fixed27         public seniorInterestRate;

    // last time the senior interest has been updated
    uint            public lastUpdateSeniorInterest;

    Fixed27         public maxSeniorRatio;
    Fixed27         public minSeniorRatio;

    uint            public maxReserve;

    TrancheLike     public seniorTranche;
    TrancheLike     public juniorTranche;
    NAVFeedLike     public navFeed;
    ReserveLike     public reserve;

    constructor() public {
        wards[msg.sender] = 1;
        seniorInterestRate.value = ONE;
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
        } else if (contractName == "reserve") {
            reserve = ReserveLike(addr);
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

    function reBalance(uint seniorAsset_, uint seniorRatio_) internal {
        // re-balancing according to new ratio
        // we use the approximated NAV here because during the submission period
        // new loans might have been repaid in the meanwhile which are not considered in the epochNAV
        seniorDebt_ = rmul(navFeed.approximatedNAV(), seniorRatio_);
        if(seniorDebt_ > seniorAsset_) {
            seniorDebt_ = seniorAsset_;
            seniorBalance_ = 0;
            return;
        }
        seniorBalance_ = safeSub(seniorAsset_, seniorDebt_);
    }

    function changeSeniorAsset(uint seniorRatio_, uint seniorSupply, uint seniorRedeem) external auth {
        dripSeniorDebt();
        uint seniorAsset = safeSub(safeAdd(safeAdd(seniorDebt_, seniorBalance_),seniorSupply), seniorRedeem);
        reBalance(seniorAsset, seniorRatio_);
        seniorRatio = Fixed27(seniorRatio_);
    }

    function seniorRatioBounds() public view returns (uint minSeniorRatio_, uint maxSeniorRatio_) {
        return (minSeniorRatio.value, maxSeniorRatio.value);
    }

    function calcUpdateNAV() external returns (uint) {
         return navFeed.calcUpdateNAV();
    }

    function calcSeniorTokenPrice() external view returns(uint) {
        return calcSeniorTokenPrice(navFeed.currentNAV(), reserve.totalBalance());
    }

    function calcJuniorTokenPrice() external view returns(uint) {
        return calcJuniorTokenPrice(navFeed.currentNAV(), reserve.totalBalance());
    }

    function calcTokenPrices() external view returns (uint, uint) {
        uint epochNAV = navFeed.currentNAV();
        uint epochReserve = reserve.totalBalance();
        return calcTokenPrices(epochNAV, epochReserve);
    }

    function calcTokenPrices(uint epochNAV, uint epochReserve) public view returns (uint, uint) {
        return (calcJuniorTokenPrice(epochNAV, epochReserve), calcSeniorTokenPrice(epochNAV, epochReserve));
    }

    function calcSeniorTokenPrice(uint epochNAV, uint epochReserve) public view returns(uint) {
        if ((epochNAV == 0 && epochReserve == 0) || seniorTranche.tokenSupply() == 0) {
            // initial token price at start 1.00
            return ONE;
        }
        uint totalAssets = safeAdd(epochNAV, epochReserve);
        uint seniorAssetValue = calcSeniorAssetValue(seniorDebt(), seniorBalance_);

        if(totalAssets < seniorAssetValue) {
            seniorAssetValue = totalAssets;
        }
        return rdiv(seniorAssetValue, seniorTranche.tokenSupply());
    }

    function calcJuniorTokenPrice(uint epochNAV, uint epochReserve) public view returns(uint) {
        if ((epochNAV == 0 && epochReserve == 0) || juniorTranche.tokenSupply() == 0) {
            // initial token price at start 1.00
            return ONE;
        }
        uint totalAssets = safeAdd(epochNAV, epochReserve);
        uint seniorAssetValue = calcSeniorAssetValue(seniorDebt(), seniorBalance_);

        if(totalAssets < seniorAssetValue) {
            return 0;
        }

        return rdiv(safeSub(totalAssets, seniorAssetValue), juniorTranche.tokenSupply());
    }

    /// repayment update keeps track of senior bookkeeping for repaid loans
    /// the seniorDebt needs to be decreased
    function repaymentUpdate(uint currencyAmount) public auth {
        dripSeniorDebt();

        uint decAmount = rmul(currencyAmount, seniorRatio.value);

        if (decAmount > seniorDebt_) {
            seniorBalance_ = calcSeniorAssetValue(seniorDebt_, seniorBalance_);
            seniorDebt_ = 0;
            return;
        }

        seniorBalance_ = safeAdd(seniorBalance_, decAmount);
        // seniorDebt needs to be decreased for loan repayments
        seniorDebt_ = safeSub(seniorDebt_, decAmount);
        lastUpdateSeniorInterest = block.timestamp;

    }
    /// borrow update keeps track of the senior bookkeeping for new borrowed loans
    /// the seniorDebt needs to be increased to accumulate interest
    function borrowUpdate(uint currencyAmount) public auth {
        dripSeniorDebt();

        // the current senior ratio defines
        // interest bearing amount (seniorDebt) increase
        uint incAmount = rmul(currencyAmount, seniorRatio.value);

        // this case should most likely never happen
        if (incAmount > seniorBalance_) {
            // all the currency of senior is used as interest bearing currencyAmount
            seniorDebt_ = calcSeniorAssetValue(seniorDebt_, seniorBalance_);
            seniorBalance_ = 0;
            return;
        }

        // seniorDebt needs to be increased for loan borrows
        seniorDebt_ = safeAdd(seniorDebt_, incAmount);
        seniorBalance_ = safeSub(seniorBalance_, incAmount);
        lastUpdateSeniorInterest = block.timestamp;
    }

    function calcSeniorAssetValue(uint _seniorDebt, uint _seniorBalance) public pure returns(uint) {
        return safeAdd(_seniorDebt, _seniorBalance);
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

    function seniorBalance() public view returns (uint) {
        return seniorBalance_;
    }
}
