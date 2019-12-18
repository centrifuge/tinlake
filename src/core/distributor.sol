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

pragma solidity >=0.4.24;

import "../../lib/dss-add-ilk-spell/lib/dss-deploy/lib/dss/src/lib.sol";

contract Distributor is DSNote {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // if capital should flow through, all funds in reserve should be moved in pile
    function tradFlow(bool poolClosing) public auth {
        if (!poolClosing) {
            // calculates how much money is in the reserve, transfers all of this balance to the pile
            for (uint i = 0; i < tranches.length; i++) {
                uint wadR = tranches[i].operator.balance();
                tranches[i].operator.borrow(address(pile), uint(wadR));
            }
        } else {
            // payout
            distributor.waterfallRepay();
        }
    }

    function customFlow(bool boolClosing) public auth {
        uint remaining;
        int wad = pile.want();
        if (wad > 0) {
            for (uint i = 0; i < tranches.length; i++) {
                wad = pile.want();
                uint wadR = tranches[i].operator.balance();
                if (wad < wadR) {
                   tranches[i].operator.borrow(address(pile), uint(wad));
                } else {
                    remaining = wad - wadR;
                }
            }

            // transfer from reserve only how much the pile wants
            t.operator.borrow(address(pile), uint(wad));
        } else {
            // this should take the money from the pile, repay and close the vault
            distributor.makerRepay();
        }
    }

    // max_take is how much liquidity can be taken out from a specific tranche,
    // given the current equity reserve/equity debt, in order to maintain the equity ratio which has been set by the pool manager.

    // max_take =  (Equity.Reserve + Equity.Debt)/Equity.Ratio * Senior.Ratio - Senior.Debt
}
