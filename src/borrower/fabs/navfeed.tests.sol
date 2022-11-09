// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import {TestNAVFeed} from "test/borrower/feed/navfeed.tests.sol";

contract TestNAVFeedFab {
    uint256 constant ONE = 10 ** 27;

    function newFeed() public returns (address) {
        TestNAVFeed feed = new TestNAVFeed();

        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
