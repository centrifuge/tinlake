// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Reserve } from "./../reserve.sol";

interface ReserveFabLike {
    function newReserve(address) external returns (address);
}

contract ReserveFab {
    function newReserve(address currency) public returns (address) {
        Reserve reserve = new Reserve(currency);
        reserve.rely(msg.sender);
        reserve.deny(address(this));
        return address(reserve);
    }
}
