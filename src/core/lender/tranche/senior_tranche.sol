// Copyright (C) 2019 Centrifuge
//
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

pragma solidity >=0.5.12;

import "./tranche.sol";
import "tinlake-math/interest.sol";

// SeniorTranche
// Interface to the senior tranche. keeps track of the current debt towards the tranche.
contract SeniorTranche is Tranche, Interest {

    uint internal debt_;             // debt of the senior tranche
    uint public ratePerSecond;      // interest rate per second in RAD (10^27)
    uint public lastUpdated;        // Last time the accumlated rate has been updated

    function debt() public returns(uint) {
        drip();
        return debt_;
    }

    constructor(address token_, address currency_) Tranche(token_ ,currency_) public {
        ratePerSecond = ONE;
        lastUpdated = now;
    }

    function file(bytes32 what, uint ratePerSecond_) public note auth {
         if (what ==  "rate") {
            drip();
            ratePerSecond = ratePerSecond_;
        }
    }

    function repay(address usr, uint currencyAmount) public note auth {
        drip();
        debt_ = safeSub(debt_, currencyAmount);
        super.repay(usr, currencyAmount);

    }

    function borrow(address usr, uint currencyAmount) public note auth {
        drip();
        debt_ = safeAdd(debt_, currencyAmount);
        super.borrow(usr, currencyAmount);
    }

    function drip() internal {
        if (now >= lastUpdated) {
            // todo move to tinlake-math
            debt_ = rmul(rpow(ratePerSecond, now - lastUpdated, ONE), debt_);
            lastUpdated = now;
        }
    }
}
