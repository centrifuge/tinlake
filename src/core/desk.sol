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

contract DistributorLike {
    function tradFlow(bool) public;
    function customFlow(bool) public;
}

contract OperatorLike {
    function borrow(address, uint) public;
    function repay(address, uint) public;
    function balance() public returns (uint);
    function file(bytes32, bool) public;

    bool public supplyActive;
    bool public redeemActive;
}

// Desk
// Keeps track of the tranches. Manages the interfacing between the tranche side and borrower side of the contracts.
contract Desk is DSNote {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Tranches ---

    struct Tranche {
        uint ratio;
        OperatorLike operator;
    }

    Tranche[] tranches;

    // --- Data ---
    PileLike public pile;
    DistributorLike public distributor;

    bool public flowThrough;
    bool public poolClosing;

    constructor (address pile_, address distributor_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
        distributor = DistributorLike(distributor_);
        flowThrough = false;
        poolClosing = false;
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "distributor") { distributor = DistributorLike(addr); }
        else revert();
    }

    function file(bytes32 what, bool data) public auth {
        if (what == "flowThrough") { flowThrough = data; }
        if (what == "poolClosing") { poolClosing = data; }
    }

    // --- Calls ---

    // TIN tranche should always be added first
    function addTranche(uint ratio, address operator_) public auth {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = OperatorLike(operator_);
        tranches.push(t);
    }

    function returnOperator(uint i) public auth returns (address){
       return address(tranches[i].operator);
    }

    function returnRatio(uint i) public auth returns (uint) {
        return tranches[i].ratio;
    }

//    function returnEquityRatios

    function balance() public auth {
        if (flowThrough) {
            distributor.tradFlow();
        } else {
            distributor.customFlow();
        }
    }

    // Note: assumes two tranche setup for now
    function calcMaxTake() public auth {

    }

    // max_take is how much liquidity can be taken out from a specific tranche,
    // given the current equity reserve/equity debt, in order to maintain the equity ratio which has been set by the pool manager.

    // max_take =  (Equity.Reserve + Equity.Debt)/Equity.Ratio * Senior.Ratio - Senior.Debt


}