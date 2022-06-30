// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";
import "../writeoffWrapper.sol";
// import "../../pile.sol";
// import "../../feed/navfeed.sol";

import "../../test/mock/pile.sol";
import "../../test/mock/feed.sol";

contract DeployerTest is DSTest {
    WriteoffWrapper writeoffWrapper;
    PileMock pile;
    NAVFeedMock navFeed;

    function setUp() public {
        writeoffWrapper = new WriteoffWrapper();
        pile = new PileMock();
        navFeed = new NAVFeedMock();
   }

   function testWriteoff() public {
        writeoffWrapper.writeOff(1, address(pile), address(navFeed));
        assertEq(pile.calls["changeRate"], 1);
   }

   function testFailWriteoffLoanNotOverDue() public {

   }

   function testFailWriteoffNotAuthorized() public {
        
   }
}