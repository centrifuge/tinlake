// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;


import "tinlake-math/interest.sol";
import { BaseTypes } from "../../../lender/test/coordinator-base.t.sol";
import { Bookrunner } from "../../../lender/bookrunner.sol";
import "../../../lender/test/mock/memberlist.sol";

import "../test_suite.sol";

contract UnderwriterSystemTest is TestSuite, Interest {

    // --- Setup ---
    Bookrunner bookrunner;

    function setUp() public {
        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);

        baseSetup();
        createTestUsers();

        bookrunner = new Bookrunner();
        bookrunner.depend("juniorToken", address(juniorToken));
        bookrunner.depend("navFeed", address(nftFeed));

        MemberlistMock memberlist = new MemberlistMock();
        bookrunner.depend("memberlist", address(memberlist));
        memberlist.updateMember(address(this), type(uint256).max);
    }

    // --- Tests ---
    function testCeilingOfUnstakedLoan() public {
        invest(700 ether, 300 ether);
        uint nftPrice = 200 ether;
        (uint tokenId, uint loan) = prepLoan(nftPrice);

        // nftFeed isnt linked to the bookrunner, so the ceiling is still > 0
        assertEqTol(nftFeed.currentCeiling(loan), nftPrice, "ceilingPreDepend");

        wireBookrunner();
        assertEqTol(nftFeed.currentCeiling(loan), 0, " ceilingPostDepend");
    }

    function testWithdrawUnstakedLoan() public {
        invest(700 ether, 300 ether);
        uint nftPrice = 200 ether;
        (uint tokenId, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        Borrower(borrower_).withdraw(loan, nftPrice, borrower_);
    }

    // --- Utils ---
    function invest(uint seniorSupplyAmount, uint juniorSupplyAmount) internal {
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        ModelInput memory submission = ModelInput({
            seniorSupply : seniorSupplyAmount,
            juniorSupply : juniorSupplyAmount,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
        });

        hevm.warp(block.timestamp + 1 days);

        closeEpoch(false);
        int valid = submitSolution(address(coordinator), submission);
        assertEq(valid, coordinator.NEW_BEST());

        hevm.warp(block.timestamp + 2 hours);

        coordinator.executeEpoch();
        assertEqTol(reserve.totalBalance(), seniorSupplyAmount + juniorSupplyAmount, " reserveAfterInvest");
    }

    function prepLoan(uint nftPrice) internal returns (uint, uint) {
        uint borrowAmount = 100 ether;
        uint maturity = 5 days;

        uint tokenId = collateralNFT.issue(borrower_);
        uint loan = setupLoan(tokenId, collateralNFT_, nftPrice, DEFAULT_RISK_GROUP_TEST_LOANS, block.timestamp + maturity);
        borrow(loan, tokenId, borrowAmount, false);

        return (tokenId, loan);
    }

    function wireBookrunner() internal {
        admin.relyNftFeed(address(this));
        nftFeed.depend("bookrunner", address(bookrunner));
    }

 }
