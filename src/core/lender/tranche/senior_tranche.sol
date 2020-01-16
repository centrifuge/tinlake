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

// SeniorTranche
// Interface to the senior tranche. keeps track of the current debt towards the tranche. 
contract SeniorTranche is Tranche {
    
    uint internal chi;              // accumulated interest over time
    uint public ratePerSecond;      // interest rate per second in RAD (10^27)
    uint public lastUpdated;        // Last time the accumlated rate has been updated

    uint internal pie;              // denominated as debt/chi. denominated in RAD (10^27)

    uint256 constant ONE = 10 ** 27;

    function debt() public returns(uint) {
        drip();
        return rmul(pie, chi);
    }

    function toPie(uint amount) internal returns(uint) {
        return rdiv(amount, chi);
    }

    constructor(address token_, address currency_) Tranche(token_ ,currency_) public {
        chi = ONE;
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
        pie = sub(pie, toPie(currencyAmount));
        super.repay(usr, currencyAmount);

    }

    function borrow(address usr, uint currencyAmount) public note auth {
        drip();
        pie = add(pie, toPie(currencyAmount));
        super.borrow(usr, currencyAmount);
    }

    function drip() internal {
        if (now >= lastUpdated) {
            chi = rmul(rpow(ratePerSecond, now - lastUpdated, ONE), chi);
            lastUpdated = now;
        }
    }

    // todo can be removed after using Tinlake-Math
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }
}
