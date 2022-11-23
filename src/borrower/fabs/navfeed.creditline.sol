// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import {CreditlineNAVFeed} from "./../feed/creditline.sol";

/// @notice factory contract for creditline nav feed
contract CreditlineNAVFeedFab {
    function newFeed() public returns (address) {
        CreditlineNAVFeed feed = new CreditlineNAVFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
