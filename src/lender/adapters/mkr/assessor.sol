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

import "./../../assessor.sol";

interface ClerkLike {
    function remainingCredit() external view returns (uint);
    function juniorStake() external view returns (uint);
    function remainingOvercollCredit() external view returns (uint);
    function stabilityFee() external view returns(uint);
    function debt() external view returns(uint);
}

contract MKRAssessor is Assessor {
    ClerkLike public clerk;

    uint public creditBufferTime = 10 days;

    function file(bytes32 name, uint value) public auth {
        if(name == "creditBufferTime") {
            creditBufferTime = value;
            return;
        }
        super.file(name, value);
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "clerk") {
            clerk = ClerkLike(addr);
        } else {
            super.depend(contractName, addr);
        }
    }

    // calculates the tokenPrice based on the nav and the reserve
    function calcSeniorTokenPrice(uint nav_, uint) public view returns(uint) {
        // the coordinator interface will pass the reserveAvailable
        uint reserve_ = reserve.totalBalance();
        if ((nav_ == 0 && reserve_ == 0) || seniorTranche.tokenSupply() == 0) {
            // initial token price at start 1.00
            return ONE;
        }

        // reserve includes creditline from maker
        uint totalAssets = safeAdd(nav_, reserve_);

        // includes creditline
        uint seniorAssetValue = calcExpectedSeniorAsset(seniorDebt(), seniorBalance_);

        if(totalAssets < seniorAssetValue) {
            seniorAssetValue = totalAssets;
        }
        return rdiv(seniorAssetValue, seniorTranche.tokenSupply());
    }

    function calcJuniorTokenPrice(uint nav_, uint) public view returns (uint) {
        uint reserve_ = reserve.totalBalance();
        if ((nav_ == 0 && reserve_ == 0) || juniorTranche.tokenSupply() == 0) {
            // initial token price at start 1.00
            return ONE;
        }
        // reserve includes creditline from maker
        uint totalAssets = safeAdd(nav_, reserve_);

        // includes creditline from mkr
        uint seniorAssetValue = calcExpectedSeniorAsset(seniorDebt(), seniorBalance_);

        if(totalAssets < seniorAssetValue) {
            return 0;
        }

        // the junior tranche only needs to pay for the mkr over-collateralization if
        // the mkr vault is liquidated, if that is true juniorStake=0
        return rdiv(safeAdd(safeSub(totalAssets, seniorAssetValue), clerk.juniorStake()),
                juniorTranche.tokenSupply());
    }

    function seniorBalance() public view returns(uint) {
        return safeAdd(seniorBalance_, clerk.remainingOvercollCredit());
    }

    function effectiveSeniorBalance() public view returns(uint) {
        return seniorBalance_;
    }

    function effectiveTotalBalance() public view returns(uint) {
        return reserve.totalBalance();
    }

    function totalBalance() public view returns(uint) {
        uint debt = clerk.debt();
        // over the time the remainingCredit will decrease because of the accumulated debt interest
        // therefore a buffer is reduced from the  remainingCredit to prevent the usage of currency which is not available
        uint debtIncrease = safeSub(chargeInterest(debt, clerk.stabilityFee(), safeAdd(block.timestamp, creditBufferTime)), debt);

        if(clerk.remainingCredit() > debtIncrease) {
            return safeAdd(reserve.totalBalance(), safeSub(clerk.remainingCredit(), debtIncrease));
        }

        return reserve.totalBalance();
    }

    // returns the current NAV
    function currentNAV() public view returns(uint) {
        return navFeed.currentNAV();
    }

    // returns the approximated NAV for gas-performance reasons
    function getNAV() public view returns(uint) {
        return navFeed.approximatedNAV();
    }

    // changes the total amount available for borrowing loans
    function changeBorrowAmountEpoch(uint currencyAmount) public auth {
        reserve.file("currencyAvailable", currencyAmount);
    }
}
