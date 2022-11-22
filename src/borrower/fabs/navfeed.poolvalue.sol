// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { NAVFeedPV } from "./../feed/navfeedPV.sol";

contract PoolValueNAVFeedFab {
    function newFeed() public returns (address) {
        NAVFeedPV feed = new NAVFeedPV();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
