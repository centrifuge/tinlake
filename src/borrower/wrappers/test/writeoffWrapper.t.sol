// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";
import "../writeoffWrapper.sol";
import { Discounting } from "../../feed/discounting.sol";
// import "../../pile.sol";
// import "../../feed/navfeed.sol";

import "../../test/mock/pile.sol";
import "../../test/mock/feed.sol";

contract DeployerTest is DSTest, Discounting {
    WriteoffWrapper writeoffWrapper;
    PileMock pile;
    NAVFeedMock navFeed;

    function setUp() public {
        writeoffWrapper = new WriteoffWrapper();
        pile = new PileMock();
        navFeed = new NAVFeedMock();
   }

   function testWriteoff() public {
        navFeed.setReturn("maturityDate", block.timestamp - 60 * 60 * 24);
        navFeed.setBytes32Return("nftID", "1");
        writeoffWrapper.writeOff(1, address(pile), address(navFeed));
        assertEq(pile.calls("changeRate"), 1);
   }

   function testFailWriteoffLoanNotOverDue() public {
        navFeed.setReturn("maturityDate", block.timestamp + 60 * 60 * 24);
        navFeed.setBytes32Return("nftID", "1");
        writeoffWrapper.writeOff(1, address(pile), address(navFeed));
   }
}