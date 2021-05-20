// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Shelf } from "./../shelf.sol";

contract ShelfFab {
    function newShelf(address tkn_, address title_, address debt_, address ceiling_) public returns (address) {
        Shelf shelf = new Shelf(tkn_, title_, debt_, ceiling_);
        shelf.rely(msg.sender);
        shelf.deny(address(this));
        return address(shelf);
    }
}
