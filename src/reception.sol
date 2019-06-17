// Copyright (C) 2019 lucasvo

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

import { TitleOwned } from "./title.sol";

contract DeskLike {
    // --- Desk ---
    function balance() public;
}

contract ShelfLike {
    function release (uint loan, address usr) public;
    function deposit (uint loan, address usr) public;
}

contract PileLike {
    function withdraw(uint loan, uint wad, address usr) public;
    function repay(uint loan, uint wad, address usr) public ;
    function balanceOf(uint loan) public view returns (uint);
}

// Reception serves as an interface for the borrower in Tinlake.
contract Reception is TitleOwned {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    DeskLike desk;
    ShelfLike shelf;
    PileLike pile;

    constructor (address desk_, address title_, address shelf_, address pile_) TitleOwned(title_) public {
        wards[msg.sender] = 1;
        desk = DeskLike(desk_);
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
    }

    // --- Reception ---
    function borrow(uint loan, address deposit) public owner(loan) {
        shelf.deposit(loan, msg.sender);
        desk.balance();

        // borrow max amount
        uint wad = pile.balanceOf(loan);
        pile.withdraw(loan, wad, deposit);

    }

    function repay(uint loan, uint wad, address usrT, address usr) public owner(loan) {
        pile.repay(loan,wad,usrT);
        shelf.release(loan, usr);
        desk.balance();
    }    
}
