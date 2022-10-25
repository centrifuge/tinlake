// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";
import "../writeOffWrapper.sol";
import { Discounting } from "../../feed/discounting.sol";
// import "../../pile.sol";
// import "../../feed/navfeed.sol";

import "../../test/mock/pile.sol";
import "../../test/mock/feed.sol";

contract WriteOffTest is DSTest, Discounting {
    WriteOffWrapper writeOffWrapper;
    PileMock pile;
    NAVFeedMock navFeed;

    function setUp() public {
        writeOffWrapper = new WriteOffWrapper();
        pile = new PileMock();
        navFeed = new NAVFeedMock();
   }

   function testWriteOff() public {
        navFeed.setReturn("maturityDate", block.timestamp - 60 * 60 * 24);
        navFeed.setBytes32Return("nftID", "1");
        navFeed.setReturn("pile", address(pile));
        writeOffWrapper.writeOff(1, address(navFeed));
        assertEq(pile.calls("changeRate"), 1);
   }

   function testFailWriteOffLoanNotOverDue() public {
        navFeed.setReturn("maturityDate", block.timestamp + 60 * 60 * 24);
        navFeed.setBytes32Return("nftID", "1");
        writeOffWrapper.writeOff(1, address(navFeed));
   }
}