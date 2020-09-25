// Copyright (C) 2020 Centrifuge

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

pragma solidity >=0.5.15 <0.6.0;

import { Shelf } from "./../shelf.sol";

interface ShelfFabLike {
    function newShelf(address, address, address, address) external returns (address);
}

contract ShelfFab {
    function newShelf(address tkn_, address title_, address debt_, address ceiling_) public returns (address) {
        Shelf shelf = new Shelf(tkn_, title_, debt_, ceiling_);
        shelf.rely(msg.sender);
        shelf.deny(address(this));
        return address(shelf);
    }
}
