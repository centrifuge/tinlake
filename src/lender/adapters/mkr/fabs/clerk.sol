// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Clerk } from "./../clerk.sol";

contract ClerkFab {
    function newClerk(address dai, address collateral) public returns (address) {
        Clerk clerk = new Clerk(dai, collateral);
        clerk.rely(msg.sender);
        clerk.deny(address(this));
        return address(clerk);
    }
}
