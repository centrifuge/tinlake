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

import "./ticker.sol";
import "tinlake-auth/auth.sol";
import "./data_types.sol";
import "tinlake-math/interest.sol";

interface NAVFeedLike {
    function currentNAV() external;
}

interface TrancheLike {
    function tokenSupply() public returns (uint);
}

contract Assessor is Auth, DataTypes, Interest  {
    // senior ratio from the last epoch executed
    Fixed27 public lastSeniorRatio;
    uint public seniorDebt;
    uint public seniorBalance;

    // system parameter

    // interest rate per second for senior tranche
    Fixed27 public seniorInterestRate;
    Fixed27 public maxSeniorRatio;
    Fixed27 public minSeniorRatio;

    uint public maxReserve;

    TrancheLike seniorTranche;
    TrancheLike juniorTranche;
    NAVFeedLike navFeed;

    constructor() public {
        wards[msg.sender] = 1;
        seniorInterestRate.value = ONE;
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
            seniorInterestRate  = Fixed27(value);
        }
        else if (name == "maxReserve") {maxReserve = value;}
        else if (name == "maxSeniorRatio") {
            require(value > minSeniorRatio.value);
            maxSeniorRatio = Fixed27(value);
        }
        else if (name == "minSeniorRatio") {
            require(value < maxSeniorRatio.value);
            minSeniorRatio = Fixed27(value);
        }
        else {revert("unkown-variable");}
    }

    function updateSenior(uint seniorDebt_, uint seniorBalance_) external auth {
        seniorDebt = seniorDebt_;
        seniorBalance = seniorBalance_;
    }

    function seniorRatioBounds() public view returns (uint minSeniorRatio_, uint maxSeniorRatio_) {
        return (minSeniorRatio, maxSeniorRatio);
    }

    function calcNAV() external view returns (uint) {
        return navFeed.currentNAV();
    }

    function calcSeniorTokenPrice(uint epochNAV, uint epochReserve) external returns(uint) {
        uint totalAssets = safeAdd(epochNAV, epochReserve);
        uint seniorAssetValue = safeAdd(seniorBalance, seniorDebt);
        if(totalAssets < seniorAssetValue) {
            seniorAssetValue = totalAssets;
        }

        return rdiv(seniorAssetValue, seniorTranche.totalSupply());
    }

    function calcJuniorTokenPrice(uint epochNAV, uint epochReserve) external returns(uint) {
        uint totalAssets = safeAdd(epochNAV, epochReserve);
        uint seniorAssetValue = safeAdd(seniorBalance, seniorDebt);
        if(totalAssets < seniorAssetValue) {
            return 0;
        }

        return rdiv(safeSub(totalAssets, seniorAssetValue), juniorTranche.totalSupply());
    }

    function repaymentUpdate(uint amount) public auth {
        uint decAmount = rmul(amount, lastSeniorRatio.value);
        // todo think about edge cases here
        // seniorDebt needs to be decreased for loan repayments
        seniorDebt = safeSub(seniorDebt, decAmount);
        seniorBalance = safeAdd(seniorBalance, decAmount);
    }

    function borrowUpdate(uint amount) public auth {
        uint incAmount = rmul(amount, lastSeniorRatio.value);
        // todo think about edge cases here
        // seniorDebt needs to be increased for loan borrows
        seniorDebt = safeAdd(seniorDebt, incAmount);
        seniorBalance = safeSub(seniorBalance, incAmount);
    }
}
