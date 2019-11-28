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
    function repay(uint loan, uint wad) public ;
    function balanceOf(uint loan) public view returns (uint);
    function collect(uint loan) public;
    function loans(uint loan) public returns (uint debt, uint balance, uint fee);
}

// Reception serves as an interface for the borrower in Tinlake.

// Warning: Reception should be used as a library with a proxy contract
contract Reception {
    constructor () public {}

    // --- Reception ---
    function borrow(address desk_, address pile_, address shelf_, uint loan, address deposit) public {
        ShelfLike(shelf_).deposit(loan, msg.sender);
        DeskLike(desk_).balance();

        // borrow max amount
        uint wad = PileLike(pile_).balanceOf(loan);
        PileLike(pile_).withdraw(loan, wad, deposit);
    }

    function repay(address desk_, address pile_, address shelf_, uint loan, uint wad, address usr) public {
        PileLike(pile_).repay(loan, wad);
        ShelfLike(shelf_).release(loan, usr);
        DeskLike(desk_).balance();
    }


    function close(address desk_, address pile_, address shelf_, uint loan, address usr) public {
        PileLike(pile_).collect(loan);
        (uint debt,,) = PileLike(pile_).loans(loan);
        repay(desk_, pile_, shelf_, loan, debt , usr);
    }
}
