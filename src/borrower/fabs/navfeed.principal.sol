// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import {NAVFeed} from "./../feed/navfeed.sol";

contract PrincipalNAVFeedFab {
    function newFeed() public returns (address) {
        NAVFeed feed = new NAVFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
