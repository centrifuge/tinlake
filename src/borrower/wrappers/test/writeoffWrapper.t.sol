// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";
import "../writeOffWrapper.sol";
import { Discounting } from "../../feed/discounting.sol";
// import "../../pile.sol";
// import "../../feed/navfeed.sol";

import "../../test/mock/pile.sol";
import "../../test/mock/feed.sol";
import "../../test/mock/shelf.sol";

contract WriteOffTest is DSTest, Discounting {
    WriteOffWrapper writeOffWrapper;
    PileMock pile;
    NAVFeedMock navFeed;
    ShelfMock shelf;

    function setUp() public {
          writeOffWrapper = new WriteOffWrapper();
          pile = new PileMock();
          navFeed = new NAVFeedMock();
          shelf = new ShelfMock();
     }

     function testFile() public {
          writeOffWrapper.file("writeOffRates", address(pile), 1000);
          assertEq(writeOffWrapper.writeOffRates(address(pile)), 1000);     
     }

     function testFailFileNotAuthorized() public {
          writeOffWrapper.deny(address(this));
          writeOffWrapper.file("writeOffRates", address(pile), 1000);
     }

     function testWriteOff() public {
          // Add NAVFeedMock to writeOffRates mapping
          writeOffWrapper.file("writeOffRates", address(pile), 1000);

          // set mock data
          navFeed.setReturn("maturityDate", block.timestamp - 60 * 60 * 24);
          navFeed.setBytes32Return("nftID", "1");
          shelf.setReturn("shelf", address(1));
          shelf.setReturn("shelf", 1);
          navFeed.setReturn("pile", address(pile));
          navFeed.setReturn("shelf", address(shelf));

          writeOffWrapper.writeOff(1, address(navFeed));
          assertEq(pile.calls("changeRate"), 1);
     }

     function testFailWriteOffPileWithoutWriteOffGroup() public {
          // set mock data
          navFeed.setReturn("maturityDate", block.timestamp - 60 * 60 * 24);
          navFeed.setBytes32Return("nftID", "1");
          shelf.setReturn("shelf", address(1));
          shelf.setReturn("shelf", 1);
          navFeed.setReturn("pile", address(pile));
          navFeed.setReturn("shelf", address(shelf));

          writeOffWrapper.writeOff(1, address(navFeed));
          assertEq(pile.calls("changeRate"), 1);
     }

     function testFailWriteOffWithNonexistantLoan() public {
          // set mock data
          navFeed.setReturn("maturityDate", block.timestamp - 60 * 60 * 24);
          navFeed.setBytes32Return("nftID", "1");
          navFeed.setReturn("pile", address(pile));
          navFeed.setReturn("shelf", address(shelf));

          writeOffWrapper.writeOff(1, address(navFeed));
          assertEq(pile.calls("changeRate"), 1);
     }

     function testFailWriteOffLoanNotOverDue() public {
          navFeed.setReturn("maturityDate", block.timestamp + 60 * 60 * 24);
          navFeed.setBytes32Return("nftID", "1");
          writeOffWrapper.writeOff(1, address(navFeed));
     }
}