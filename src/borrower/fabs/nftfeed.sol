// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { BaseNFTFeed } from "./../feed/nftfeed.sol";

interface NFTFeedFabLike {
    function newFeed() external returns (address);
}

contract NFTFeedFab {
    function newFeed() public returns (address) {
        BaseNFTFeed feed = new BaseNFTFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}
