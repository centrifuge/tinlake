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

contract PileLike {
    function want() public returns (int);
}

contract OperatorLike {
    function give(address, uint) public;
    function take(address, uint) public;
}

contract Desk {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    PileLike public pile;
    OperatorLike public operator;

    constructor (address pile_, address operator_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
        operator = OperatorLike(operator_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "operator") { operator = OperatorLike(addr); }
        else revert();
    }

    // --- Calls ---
    function balance() public auth {
        int wad = pile.want();
        if (wad > 0) {
            operator.take(address(pile), uint(wad));

        } else {
            operator.give(address(pile), uint(wad*-1));
        }
    }
}