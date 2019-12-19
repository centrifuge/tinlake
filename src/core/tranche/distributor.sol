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

import "ds-note/note.sol";

contract PileLike {
    function want() public returns (int);
}

contract QuantLike {
    uint public debt;
}

contract OperatorLike {

    function borrow(address, uint) public;
    function repay(address, uint) public;
    function balance() public returns (uint);
    function file(bytes32, bool) public;

    bool public supplyActive;
    bool public redeemActive;

    QuantLike public quant;
}

contract Distributor is DSNote {

    // --- Tranches ---

    struct Tranche {
        uint ratio;
        OperatorLike operator;
    }

    Tranche[] tranches;

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    PileLike public pile;

    constructor (address pile_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else revert();
    }

    // TIN tranche should always be added first
    function addTranche(uint ratio, address operator_) public auth {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = OperatorLike(operator_);
        tranches.push(t);
    }

    function ratioOf(uint i) public auth returns (uint) {
        return tranches[i].ratio/100;
    }

    // this function assumes two tranches only
    function equityRatio() public auth returns (uint) {
        return tranches[0].ratio;
    }

    // if capital should flow through, all funds in reserve should be moved in pile
    function tradFlow(bool poolClosing) public auth {
        if (!poolClosing) {
            for (uint i = 0; i < tranches.length; i++) {
                // calculates how much money is in the reserve, transfers all of this balance to the pile
                uint wadR = tranches[i].operator.balance();
                tranches[i].operator.borrow(address(pile), uint(wadR));
                }
        } else {
            // payout
            waterfallRepay();
        }
    }

    function customFlow(bool poolClosing) public auth {
        if (!poolClosing) {
            poolOpen();
        } else {
            // this should take the money from the pile, repay and close the vault
            waterfallRepay();
        }
    }

    function poolOpen() private {
        int wad = pile.want();
        // pile wants money
        if (wad > 0) {
            pileWants();
        } else if (wad < 0) {
            pileHas();
        }
    }

    function pileWants() private {
        int wad = pile.want();
        // should always take money from the equity tranche first
        for (uint i = 0; i < tranches.length; i++) {
            uint wadR = tranches[i].operator.balance();
            // this can be cast into uint bc wad should always be positive at this point
            if (uint(wad) < wadR) {
                tranches[i].operator.borrow(address(pile), uint(wad));
                wad = 0;
            } else {
                tranches[i].operator.borrow(address(pile), uint(wadR));
                wad = int(uint(wad) - wadR);
            }
        }
    }

    function pileHas() private {
        int wad = pile.want();
        // pile has extra money, this can be repaid into the reserve
        // senior tranche should always be the last tranche in the array and be repaid first
        for (int i = int(tranches.length - 1); i > int(-1); i--) {
            QuantLike quant = tranches[uint(i)].operator.quant();
            int wadD = int(quant.debt());
            // positive number here means there is some debt in the senior tranche
            if (wad < int(wadD*-1) && wadD > 0) {
                // wadD cast to uint bc it should be positive here
                tranches[uint(i)].operator.repay(address(pile), uint(wadD));
                wad = wad + wadD;
            } else {
                // wad cast to uint bc it should be positive here
                tranches[uint(i)].operator.repay(address(pile), uint(wad));
                wad = 0;
            }
        }
    }

    function waterfallRepay() private {
        // take all the money from the pile, pay sr tranche debt first, then pay jr tranche debt
    }

    // Note: assumes two tranche setup for now
    // this should be a separate contract module, in case we want to modify calculations
    function calcMaxTake() public auth {

    }

    // max_take is how much liquidity can be taken out from a specific tranche,
    // given the current equity reserve/equity debt, in order to maintain the equity ratio which has been set by the pool manager.

    // max_take =  (Equity.Reserve + Equity.Debt)/Equity.Ratio * Senior.Ratio - Senior.Debt
}
