// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;


import "tinlake-math/interest.sol";
import { BaseTypes } from "../../../lender/test/coordinator-base.t.sol";
import { Bookrunner} from "../../../lender/bookrunner.sol";
import { Underwriter } from "../users/underwriter.sol";

import "../test_suite.sol";

contract UnderwriterSystemTest is TestSuite, Interest {

    // --- Setup ---
    Bookrunner bookrunner;

    Underwriter public issuer;
    Underwriter public underwriter;

    function setUp() public {
        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);

        baseSetup();
        createTestUsers();

        bookrunner = new Bookrunner();
        bookrunner.depend("juniorToken", address(juniorToken));
        bookrunner.depend("navFeed", address(nftFeed));

        Memberlist memberlist = new Memberlist();
        bookrunner.depend("memberlist", address(memberlist));

        issuer = new Underwriter(address(bookrunner), address(juniorToken), address(juniorOperator));
        memberlist.updateMember(address(issuer), type(uint256).max);

        underwriter = new Underwriter(address(bookrunner), address(juniorToken), address(juniorOperator));
        memberlist.updateMember(address(underwriter), type(uint256).max);

        root.relyContract(address(juniorToken), address(this));
    }

    // --- Tests ---
    function testCeilingOfUnstakedLoan() public {
        invest(700 ether, 300 ether);
        uint nftPrice = 200 ether;
        (, uint loan) = prepLoan(nftPrice);

        // nftFeed isnt linked to the bookrunner, so the ceiling is still > 0
        assertEqTol(nftFeed.currentCeiling(loan), nftPrice, "ceilingPreDepend");

        wireBookrunner();
        assertEqTol(nftFeed.currentCeiling(loan), 0, " ceilingPostDepend");
    }

    function testFailWithdrawUnstakedLoan() public {
        invest(700 ether, 300 ether);
        uint nftPrice = 200 ether;
        (, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testFailWithdrawInsufficientlyStakedLoan() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        (bytes32 nftID, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        proposeAndStake(nftID, risk, value, 10 ether, 0 ether);
        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testFailWithdrawNonAcceptedLoan() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        (bytes32 nftID, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        proposeAndStake(nftID, risk, value, 10 ether, 50 ether);
        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testFailAcceptLoanBeforeChallengePeriodEnded() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        (bytes32 nftID, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        proposeAndStake(nftID, risk, value, 10 ether, 50 ether);
        issuer.accept(nftID, risk, value);
    }

    function testWithdrawAcceptedLoan() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        (bytes32 nftID, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        proposeAndStake(nftID, risk, value, 10 ether, 50 ether);
        hevm.warp(block.timestamp + 1 hours);

        assertEqTol(nftFeed.currentCeiling(loan), 0, " ceilingPreAccept");
        issuer.accept(nftID, risk, value);
        assertEqTol(nftFeed.currentCeiling(loan), nftPrice, " ceilingPostAccept");

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testDisburseMintedTokens() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        (bytes32 nftID, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        proposeAndStake(nftID, risk, value, 10 ether, 90 ether);
        hevm.warp(block.timestamp + 1 hours);
        issuer.accept(nftID, risk, value);

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);

        hevm.warp(block.timestamp + 4 days);
        repayLoan(borrower_, loan, nftPrice);

        (uint minted, uint burned) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 1.8 ether, " minted"); // 90% of 1% of 200 ether
        assertEqTol(burned, 0 ether, " burned");

        uint preJuniorSupply = juniorToken.totalSupply();
        uint preUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        juniorTranche.disburseStaked(address(underwriter));

        uint postJuniorSupply = juniorToken.totalSupply();
        uint postUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        
        assertEqTol(postJuniorSupply - preJuniorSupply, minted, " supply increase");
        assertEqTol(postUnderwriterBalance - preUnderwriterBalance, minted, " balance increase");
    }

    // TODO: repay partially, disburse and get partial minted tokens, repay remainder, disburse and get remainder minted tokens - already minted tokens

    function testDisburseBurnedTokens() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        (bytes32 nftID, uint loan) = prepLoan(nftPrice);
        wireBookrunner();

        proposeAndStake(nftID, risk, value, 10 ether, 90 ether);
        hevm.warp(block.timestamp + 1 hours);
        issuer.accept(nftID, risk, value);

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);

        uint maturity = 5 days;
        hevm.warp(block.timestamp + maturity + 3 days); // 3 days overdue
        nftFeed.writeOff(nftID, 0); // 60% writeoff

        (uint minted, uint burned) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 0 ether, " minted 1");
        assertEqTol(burned, 1.08 ether, " burned 1"); // 90% of 1% of 60% of 200 ether

        uint preJuniorSupply = juniorToken.totalSupply();
        uint preUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        // TODO: the fact that approve() is required means that external disburse() for burning doesn't work.
        // Maybe we can solve this by blocking any staking and redemptions in the pool until disburseStaked was called?
        underwriter.approve(address(juniorTranche), burned);
        underwriter.disburseStaked();

        uint postJuniorSupply = juniorToken.totalSupply();
        uint postUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        
        assertEqTol(postJuniorSupply - preJuniorSupply, -burned, " supply decrease");
        assertEqTol(postUnderwriterBalance - preUnderwriterBalance, -burned, " balance decrease");

        hevm.warp(block.timestamp + 3 days); // 6 days overdue
        nftFeed.writeOff(nftID, 1); // 80% writeoff

        (minted, burned) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 0 ether, " minted 2");
        assertEqTol(burned, 1.44 ether - 1.08 ether, " burned 2"); // (90% of 1% of 80% of 200 ether) - 1.08 ether

        underwriter.approve(address(juniorTranche), 1.44 ether - 1.08 ether);
        (, uint secondBurn) = underwriter.disburseStaked();
        assertEqTol(burned, 1.44 ether - 1.08 ether, " secondBurn");
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

    function prepLoan(uint nftPrice) internal returns (bytes32, uint) {
        uint maturity = 5 days;

        uint tokenId = collateralNFT.issue(borrower_);
        uint loan = setupLoan(tokenId, collateralNFT_, nftPrice, DEFAULT_RISK_GROUP_TEST_LOANS, block.timestamp + maturity);

        bytes32 nftID = nftFeed.nftID(loan);
        return (nftID, loan);
    }

    function wireBookrunner() internal {
        admin.relyNftFeed(address(this));
        admin.relyJuniorTranche(address(this));

        nftFeed.depend("bookrunner", address(bookrunner));
        nftFeed.rely(address(bookrunner));

        bookrunner.rely(address(nftFeed));
        bookrunner.rely(address(juniorTranche));
        juniorTranche.depend("bookrunner", address(bookrunner));
    }

    function proposeAndStake(bytes32 nftID, uint risk, uint value, uint proposeAmount, uint stakeAmount) internal {
        juniorToken.mint(address(issuer), proposeAmount);
        issuer.propose(nftID, risk, value, proposeAmount);
        assertEqTol(bookrunner.currentStake(nftID, risk, value), proposeAmount, " postProposeStake");

        juniorToken.mint(address(underwriter), stakeAmount);
        underwriter.addStake(nftID, risk, value, stakeAmount);
        assertEqTol(bookrunner.currentStake(nftID, risk, value), proposeAmount + stakeAmount, " postAddStake");
    }

}