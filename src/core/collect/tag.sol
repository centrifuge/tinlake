// tag.sol -- knows the price for a collectable loan. Current implementation price == debt.
// in more complex scenarios the tag contract could return the selling price from an auction.
// Copyright (C) 2019 Centrifuge

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
    function loans(uint loan) public returns (uint, uint, uint ,uint);
    function collect(uint loan) public;
}

contract Tag {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    PileLike pile;

    constructor(address pile_) public {
        pile = PileLike(pile);
    }

    function price(uint loan) public returns (uint) {
        pile.collect(loan);
        (uint debt,,,) = pile.loans(loan);
        return debt;
    }
}