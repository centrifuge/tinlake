// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { NAVFeed } from "./../feed/navfeed.sol";

contract NAVFeedFab {
    function newFeed() public returns (address) {
        NAVFeed feed = new NAVFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
