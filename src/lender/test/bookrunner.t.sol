// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "./../bookrunner.sol";
import "./mock/navFeed.sol";
import "./mock/memberlist.sol";
import "../../test/simple/token.sol";

interface Hevm {
    function warp(uint256) external;
}

contract BookrunnerTest is DSTest, Math {
    Hevm hevm;

    SimpleToken juniorToken;
    NAVFeedMock navFeed;
    MemberlistMock memberlist;
    Bookrunner bookrunner;

    uint minimumDeposit_ = 10 ether;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);

        juniorToken = new SimpleToken("TIN", "Tranche");
        navFeed = new NAVFeedMock();
        memberlist = new MemberlistMock();

        bookrunner = new Bookrunner();
        bookrunner.depend("juniorToken", address(juniorToken));
        bookrunner.depend("navFeed", address(navFeed));
        bookrunner.depend("memberlist", address(memberlist));

        bookrunner.file("minimumDeposit", minimumDeposit_);
    }

    function propose(bytes32 nftID, uint risk, uint value, uint deposit) internal {
        juniorToken.mint(address(this), deposit);
        juniorToken.approve(address(bookrunner), deposit);
        bookrunner.propose(nftID, risk, value, deposit);
    }

    function testPropose(bytes32 nftID, uint risk, uint value, uint deposit) public {
        if (deposit <= minimumDeposit_) return;

        propose(nftID, risk, value, deposit);
        assertEq(bookrunner.proposals(nftID, abi.encodePacked(risk, value)), deposit);
    }

    function testFailProposeInsufficientBalance(bytes32 nftID, uint risk, uint value, uint deposit) public {
        if (deposit == 0) return // should always fail if deposit > 0, since balance = 0 by default
        bookrunner.propose(nftID, risk, value, deposit);
    }

    function testStake(uint stakeAmount) public {
        bytes32 nftID = "1";
        uint risk = 0;
        uint value = 100 ether;

        propose(nftID, risk, value, 10 ether);
        memberlist.updateMember(address(this), type(uint256).max);

        juniorToken.mint(address(this), stakeAmount);
        juniorToken.approve(address(bookrunner), stakeAmount);
        bookrunner.addStake(nftID, risk, value, stakeAmount);
    }

    function testFailStakeAsNonMember() public {
        bytes32 nftID = "1";
        uint risk = 0;
        uint value = 100 ether;

        propose(nftID, risk, value, 10 ether);

        juniorToken.mint(address(this), 1000 ether);
        juniorToken.approve(address(bookrunner), 1000 ether);
        bookrunner.addStake(nftID, risk, value, 1000 ether);
    }

}
