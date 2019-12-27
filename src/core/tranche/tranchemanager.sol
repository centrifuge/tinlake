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

contract OperatorLike {
    function balance() public returns (uint);
    function debt() public returns (uint);
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
        OperatorLike operator;
    }

    Tranche[] public tranches;

    constructor (address pile_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else revert();
    }

    // --- Calls ---
    // TIN tranche should always be added first
    // We use 10ˆ27 for the ratio. For example, a ratio of 70% is 70 * 10^27 (70)
    function addTranche(uint ratio, address operator_) public auth {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = OperatorLike(operator_);
        tranches.push(t);
    }

    function trancheCount() public auth returns (uint) {
        return tranches.length;
    }

    function poolDebt() public returns (uint) {

    }

    function trancheDebt(address trancheOperator_) public returns (uint) {

    }

    function trancheReserve(address trancheOperator_) public returns (uint) {
        
    }
} 