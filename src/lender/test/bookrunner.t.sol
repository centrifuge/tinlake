// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "./../bookrunner.sol";
import "./mock/navFeed.sol";
import "../../test/simple/token.sol";

interface Hevm {
		function warp(uint256) external;
}

contract BookrunnerTest is DSTest, Math {
    Hevm hevm;

    SimpleToken juniorToken;
    NAVFeedMock navFeed;
    Bookrunner bookrunner;

    uint minimumDeposit_ = 10 ether;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);

        juniorToken = new SimpleToken("TIN", "Tranche");
        navFeed = new NAVFeedMock();

        bookrunner = new Bookrunner();
        bookrunner.depend("juniorToken", address(juniorToken));
        bookrunner.depend("navFeed", address(navFeed));
        bookrunner.file("minimumDeposit", minimumDeposit_);
    }

    function provePropose(bytes32 nftID, uint risk, uint value, uint deposit) public {
        if (deposit <= minimumDeposit_) return;

        juniorToken.mint(address(this), deposit);
        juniorToken.approve(address(bookrunner), deposit);
        
		bytes memory proposal = abi.encodePacked(risk, value);
        bookrunner.propose(nftID, risk, value, deposit);

        assertEq(bookrunner.proposals(nftID, proposal), deposit);
    }

    function proveFailProposeInsufficientBalance(bytes32 nftID, uint risk, uint value, uint deposit) public {
        if (deposit == 0) return // should always fail if deposit > 0, since balance = 0 by default
        bookrunner.propose(nftID, risk, value, deposit);
    }
}
