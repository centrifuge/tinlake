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
    function Debt() public returns (uint); 
}

// TrancheManager
// Keeps track of the tranches. Manages the interfacing between the tranche side and borrower side of the contracts.
contract TrancheManager is DSNote {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    PileLike public pile;

    // --- Tranches ---
    struct Tranche {
        uint ratio;
        address operator;
    }

    Tranche[] public tranches;

    constructor (address pile_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
    }

    function depend (bytes32 what, address addr) public note auth {
        if (what == "pile") { pile = PileLike(addr); }
        else revert();
    }

    function addTranche(uint ratio, address operator_) public auth {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = operator_;
        tranches.push(t);
    }

    function trancheCount() public returns (uint) {
        return tranches.length;
    }

    function operatorOf(uint i) public returns (address) {
        return tranches[i].operator;
    }

    function poolValue() public returns (uint) {
        return pile.Debt();
    }

    // returns true for the tranche with the highest risk
    function isEquity(address operator_) public returns (bool) {
        return tranches[tranches.length-1].operator == operator_;
    }

    function indexOf(address operator_) public returns (int) {
        for (uint i = 0; i < tranches.length; i++) {
            if (tranches[i].operator == operator_) {
                return int(i);
            }
        }
        return -1;
    }
}