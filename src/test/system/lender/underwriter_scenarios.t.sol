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
    function testFailWithdrawUnstakedLoan() public {
        invest(700 ether, 300 ether);
        uint nftPrice = 200 ether;
        uint loan = prepLoan(5 days);
        wireBookrunner();

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testFailWithdrawInsufficientlyStakedLoan() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 0 ether);
        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testFailWithdrawNonAcceptedLoan() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 50 ether);
        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testFailAcceptLoanBeforeChallengePeriodEnded() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 50 ether);
        issuer.accept(loan, risk, value);
    }

    function testWithdrawAcceptedLoan() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 50 ether);
        hevm.warp(block.timestamp + 1 hours);

        assertEqTol(nftFeed.currentCeiling(loan), 0, " ceilingPreAccept");
        issuer.accept(loan, risk, value);
        assertEqTol(nftFeed.currentCeiling(loan), nftPrice, " ceilingPostAccept");

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);
    }

    function testDisburseMintedTokens() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 90 ether);
        hevm.warp(block.timestamp + 1 hours);
        issuer.accept(loan, risk, value);

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);

        setupRepayReq();
        uint preJuniorSupply = juniorToken.totalSupply();
        borrower.repayFullDebt(loan);
        uint postJuniorSupply = juniorToken.totalSupply();

        assertEqTol(postJuniorSupply - preJuniorSupply, 2 ether, " supply increase"); // 1% of 200 ether

        (uint minted, uint slashed, uint tokenPayout) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 1.8 ether, " minted");
        assertEqTol(slashed, 0 ether, " slashed");
        assertEqTol(tokenPayout, 0 ether, " tokenPayout pre close");
        
        borrower.close(loan);
        (,, uint tokenPayoutAfterClose) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(tokenPayoutAfterClose, 91.8 ether, " tokenPayout post close"); // 90 ether stake + 90% of 1% of 200 ether minted

        uint preUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        juniorTranche.disburseStaked(address(underwriter));
        uint postUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        assertEqTol(postUnderwriterBalance - preUnderwriterBalance, tokenPayoutAfterClose, " balance increase");
    }

    function testDisburseBurnedTokens() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 90 ether);
        hevm.warp(block.timestamp + 1 hours);
        issuer.accept(loan, risk, value);

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);

        uint maturity = 5 days;
        hevm.warp(block.timestamp + maturity + 3 days); // 3 days overdue

        uint preJuniorSupply = juniorToken.totalSupply();
        nftFeed.writeOff(loan, 0); // 60% writeoff
        uint postJuniorSupply = juniorToken.totalSupply();

        assertEqTol(preJuniorSupply - postJuniorSupply, 1.2 ether, " supply decrease"); // 1% of 60% of 200 ether

        (uint minted, uint burned, uint tokenPayout) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 0 ether, " minted 60%");
        assertEqTol(burned, 1.08 ether, " burned 60%"); // 90% of 1.2 ether
        assertEqTol(tokenPayout, 0, " tokenPayout 60%"); // not yet closed

        hevm.warp(block.timestamp + 3 days); // 6 days overdue
        nftFeed.writeOff(loan, 1); // 80% writeoff

        (minted, burned, ) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 0 ether, " minted 80%");
        assertEqTol(burned, 1.44 ether, " burned 80%"); // (90% of 1% of 80% of 200 ether)

        hevm.warp(block.timestamp + 3 days); // 9 days overdue
        nftFeed.writeOff(loan, 2); // 100% writeoff

        (minted, burned, tokenPayout) = juniorTranche.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 0 ether, " minted 100%");
        assertEqTol(burned, 1.8 ether, " burned 100%"); // (90% of 1% of 200 ether slash)
        assertEqTol(tokenPayout, 90 ether - 1.8 ether, " minted 100%"); // 90 ether stake - 90% of 1% of 200 ether slashed

        uint preUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        underwriter.disburseStaked();
        uint postUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        assertEqTol(postUnderwriterBalance - preUnderwriterBalance, tokenPayout, " balance increase after writeoff");
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

    function prepLoan(uint maturity) internal returns (uint) {
        uint tokenId = collateralNFT.issue(borrower_);
        uint loan = borrower.issue(collateralNFT_, tokenId);
        admin.setMaturityDate(collateralNFT_, tokenId, block.timestamp + maturity);

        return loan;
    }

    function wireBookrunner() internal {
        admin.relyNftFeed(address(this));
        admin.relyJuniorTranche(address(this));

        // TODO: below should be moved into a deployer contract
        admin.relyJuniorToken(address(bookrunner));
        admin.makeJuniorTokenMember(address(bookrunner), type(uint256).max);

        admin.makeJuniorTokenMember(address(issuer), type(uint256).max);
        admin.makeJuniorTokenMember(address(underwriter), type(uint256).max);

        nftFeed.depend("bookrunner", address(bookrunner));
        nftFeed.rely(address(bookrunner));

        bookrunner.rely(address(nftFeed));
        bookrunner.rely(address(juniorTranche));
        juniorTranche.depend("bookrunner", address(bookrunner));
    }

    function proposeAndStake(uint loan, uint risk, uint value, uint proposeAmount, uint stakeAmount) internal {
        juniorToken.mint(address(issuer), proposeAmount);
        issuer.approve(address(bookrunner), proposeAmount);
        issuer.propose(loan, risk, value, proposeAmount);
        assertEqTol(bookrunner.currentStake(loan, risk, value), proposeAmount, " postProposeStake");

        juniorToken.mint(address(underwriter), stakeAmount);
        underwriter.approve(address(bookrunner), stakeAmount);
        underwriter.stake(loan, risk, value, stakeAmount);
        assertEqTol(bookrunner.currentStake(loan, risk, value), proposeAmount + stakeAmount, " postAddStake");
    }

}