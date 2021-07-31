// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { PrincipalNAVFeed } from "./../feed/principal.sol";
import { CreditlineNAVFeed } from "./../feed/creditline.sol";

contract NAVFeedFab {
    function newPrincipalFeed() public returns (address) {
        PrincipalNAVFeed feed = new PrincipalNAVFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }

    function newCreditlineFeed() public returns (address) {
        CreditlineNAVFeed feed = new CreditlineNAVFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
