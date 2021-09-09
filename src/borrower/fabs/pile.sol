// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { Pile } from "./../pile.sol";

contract PileFab {
    function newPile() public returns (address) {
        Pile pile = new Pile();
        pile.rely(msg.sender);
        pile.deny(address(this));
        return address(pile);
    }
}
