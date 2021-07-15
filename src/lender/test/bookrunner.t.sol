// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "./../bookrunner.sol";
import "./../token/memberlist.sol";
import "./mock/navFeed.sol";
import "../../test/simple/token.sol";

interface Hevm {
    function warp(uint256) external;
}

contract BookrunnerTest is DSTest, Math {
    Hevm hevm;

    SimpleToken juniorToken;
    NAVFeedMock navFeed;
    Memberlist memberlist;
    Bookrunner bookrunner;

    uint minimumDeposit_ = 10 ether;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);

        juniorToken = new SimpleToken("TIN", "Tranche");
        navFeed = new NAVFeedMock();
        memberlist = new Memberlist();

        bookrunner = new Bookrunner();
        bookrunner.depend("juniorToken", address(juniorToken));
        bookrunner.depend("navFeed", address(navFeed));
        bookrunner.depend("memberlist", address(memberlist));

        bookrunner.file("minimumDeposit", minimumDeposit_);
    }

    function propose(uint loan, uint risk, uint value, uint deposit) internal {
        juniorToken.mint(address(this), deposit);
        juniorToken.approve(address(bookrunner), deposit);
        bookrunner.propose(loan, risk, value, deposit);
    }

    function testPropose(uint loan, uint risk, uint value, uint deposit) public {
        if (deposit <= minimumDeposit_) return;

        propose(loan, risk, value, deposit);
        assertEq(bookrunner.proposals(loan, abi.encodePacked(risk, value)), deposit);
    }

    // function testFailProposeInsufficientBalance(uint loan, uint risk, uint value, uint deposit) public {
    //     if (deposit == 0) return; // should always fail if deposit > 0, since balance = 0 by default
    //     if (loan > 10**6 || value > 10**(9+18) || deposit > 10**(6+18)) return;

    //     bookrunner.propose(loan, risk, value, deposit);
    // }

    function testStake(uint stakeAmount) public {
        if (stakeAmount == 0 || stakeAmount > 10**(9+18)) return; // not more than 1 billion tokens

        uint loan = 1;
        uint risk = 0;
        uint value = 100 ether;

        propose(loan, risk, value, 10 ether);
        memberlist.updateMember(address(this), type(uint256).max);

        juniorToken.mint(address(this), stakeAmount);
        juniorToken.approve(address(bookrunner), stakeAmount);
        bookrunner.stake(loan, risk, value, stakeAmount);
    }

    function testFailStakeAsNonMember() public {
        uint loan = 1;
        uint risk = 0;
        uint value = 100 ether;

        propose(loan, risk, value, 10 ether);

        juniorToken.mint(address(this), 1000 ether);
        juniorToken.approve(address(bookrunner), 1000 ether);
        bookrunner.stake(loan, risk, value, 1000 ether);
    }

}
