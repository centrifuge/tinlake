// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { PrincipalNAVFeed } from "./../feed/principal.sol";

contract NAVFeedFab {
    function newFeed() public returns (address) {
        PrincipalNAVFeed feed = new PrincipalNAVFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
