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
    function calcOvercollAmount(uint amount) external view returns (uint);
    function stabilityFee() external view returns(uint);
    function debt() external view returns(uint);
}

contract MKRAssessor is Assessor {
    ClerkLike public clerk;

    uint public creditBufferTime = 1 days;

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

    function calcSeniorTokenPrice() external view returns(uint) {
        return calcSeniorTokenPrice(navFeed.approximatedNAV(), reserve.totalBalance());
    }

    function _calcSeniorTokenPrice(uint nav_, uint reserve_) internal view returns(uint) {
        // the coordinator interface will pass the reserveAvailable

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

    // calculates the tokenPrice based on the nav and the reserve
    function calcSeniorTokenPrice(uint nav_, uint) public view returns(uint) {
        return _calcSeniorTokenPrice(nav_, reserve.totalBalance());
    }

    function _calcJuniorTokenPrice(uint nav_, uint reserve_) internal view returns (uint) {
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

    function calcJuniorTokenPrice(uint nav_, uint) public view returns (uint) {
        return _calcJuniorTokenPrice(nav_, reserve.totalBalance());
    }

    function seniorBalance() public view returns(uint) {
        return safeAdd(seniorBalance_, remainingOvercollCredit());
    }

    function effectiveSeniorBalance() public view returns(uint) {
        return seniorBalance_;
    }

    function effectiveTotalBalance() public view returns(uint) {
        return reserve.totalBalance();
    }

    function totalBalance() public view returns(uint) {
        return safeAdd(reserve.totalBalance(), remainingCredit());
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

    // returns the remainingCredit plus a buffer for the interest increase
    function remainingCredit() public view returns(uint) {
        // over the time the remainingCredit will decrease because of the accumulated debt interest
        // therefore a buffer is reduced from the  remainingCredit to prevent the usage of currency which is not available
        uint debt = clerk.debt();
        uint stabilityBuffer = safeSub(rmul(rpow(clerk.stabilityFee(),
            creditBufferTime, ONE), debt), debt);
        uint remainingCredit = clerk.remainingCredit();
        if(remainingCredit > stabilityBuffer) {
            return safeSub(remainingCredit, stabilityBuffer);
        }
        return 0;
    }

    function remainingOvercollCredit() public view returns(uint) {
        return clerk.calcOvercollAmount(remainingCredit());
    }
}
