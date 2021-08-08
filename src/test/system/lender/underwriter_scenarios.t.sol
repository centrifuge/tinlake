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
        bookrunner.depend("assessor", address(assessor));

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

    function testWithdrawAcceptedLoan() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 50 ether);
        hevm.warp(block.timestamp + 1 hours);

        assertEqTol(nftFeed.ceiling(loan), 0, " ceilingPreAccept");
        issuer.accept(loan, risk, value);
        assertEqTol(nftFeed.ceiling(loan), nftPrice, " ceilingPostAccept");

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

        (uint minted, uint slashed, uint tokenPayout) = bookrunner.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 1.8 ether, " minted");
        assertEqTol(slashed, 0 ether, " slashed");
        assertEqTol(tokenPayout, 0 ether, " tokenPayout pre close");
        
        borrower.close(loan);
        (,, uint tokenPayoutAfterClose) = bookrunner.calcStakedDisburse(address(underwriter));
        assertEqTol(tokenPayoutAfterClose, 91.8 ether, " tokenPayout post close"); // 90 ether stake + 90% of 1% of 200 ether minted

        uint preUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        bookrunner.disburse(address(underwriter));
        uint postUnderwriterBalance = juniorToken.balanceOf(address(underwriter));
        assertEqTol(postUnderwriterBalance - preUnderwriterBalance, tokenPayoutAfterClose, " balance increase");
    }

    function testSlashingEntireStake() public {
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

        uint preJuniorTokenPrice = assessor.calcJuniorTokenPrice(nftFeed.currentNAV(), reserve.totalBalance());
        uint preJuniorSupply = juniorToken.totalSupply();
        nftFeed.overrideWriteOff(loan, 0); // 60% writeoff
        closeEpoch(true);
        uint postJuniorTokenPrice = assessor.calcJuniorTokenPrice(nftFeed.currentNAV(), reserve.totalBalance());
        uint postJuniorSupply = juniorToken.totalSupply();

        emit log_named_uint("preJuniorTokenPrice", preJuniorTokenPrice);
        emit log_named_uint("postJuniorTokenPrice", postJuniorTokenPrice);

        assertTrue(postJuniorTokenPrice < preJuniorTokenPrice); // the entire stake was slashed, which means the TIN token price will go down due to the NAV drop
        assertEqTol(preJuniorSupply - postJuniorSupply, 100 ether, " supply decrease"); // min(60% of 200 ether + debt, 100 ether staked)

        (uint minted, uint burned, uint tokenPayout) = bookrunner.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 0 ether, " minted 60%");
        assertEqTol(burned, 90 ether, " burned 60%"); // 90% of 100 ether
        assertEqTol(tokenPayout, 0, " tokenPayout 60%"); // not yet closed

        hevm.warp(block.timestamp + 6 days); // 9 days overdue
        nftFeed.overrideWriteOff(loan, 2); // 100% writeoff

        (minted, burned, tokenPayout) = bookrunner.calcStakedDisburse(address(underwriter));
        assertEqTol(minted, 0 ether, " minted 100%");
        assertEqTol(burned, 90 ether, " burned 100%"); // 90% of 100 ether
        assertEqTol(tokenPayout, 0, " tokenPayout 100%"); // full stake slashed
    }

    function testSlashingPartialStake() public {
        invest(700 ether, 300 ether);
        (uint nftPrice, uint risk, uint value) = (200 ether, DEFAULT_RISK_GROUP_TEST_LOANS, 200 ether);
        uint loan = prepLoan(5 days);
        wireBookrunner();

        proposeAndStake(loan, risk, value, 10 ether, 180 ether);
        hevm.warp(block.timestamp + 1 hours);
        issuer.accept(loan, risk, value);

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, nftPrice);

        hevm.warp(block.timestamp + 1 days);
        uint startNAV = assessor.currentNAV();
        closeEpoch(true); // make sure nav is correct

        uint maturity = 5 days;
        hevm.warp(block.timestamp + maturity + 2 days); // 3 days overdue

        uint preDebt = pile.debt(loan);

        uint preJuniorTokenPrice = assessor.calcJuniorTokenPrice(nftFeed.currentNAV(), reserve.totalBalance());
        uint preNAV = assessor.currentNAV();
        uint preReserve = reserve.totalBalance();
        uint preSupply = juniorToken.totalSupply();
        nftFeed.overrideWriteOff(loan, 0); // 60% writeoff
        closeEpoch(true);
        uint postNAV = assessor.currentNAV();
        uint postJuniorTokenPrice = assessor.calcJuniorTokenPrice(nftFeed.currentNAV(), reserve.totalBalance());
        uint postReserve = reserve.totalBalance();
        uint postSupply = juniorToken.totalSupply();

        // loan debt: 295, writeoff 60% => nav should drop 177
        // nav: 226 => 177
        // reserve: 800 => 800
        // junior supply => 490 => 370

        emit log_named_uint("startNAV", startNAV);
        emit log_named_uint("preDebt", preDebt);
        emit log_named_uint("preJuniorTokenPrice", preJuniorTokenPrice);
        emit log_named_uint("preNAV", preNAV); // it's fallen out of the nav after the maturity date => 0
        emit log_named_uint("preReserve", preReserve);
        emit log_named_uint("preSupply", preSupply);
        emit log_named_uint("postNAV", postNAV);
        emit log_named_uint("postJuniorTokenPrice", postJuniorTokenPrice);
        emit log_named_uint("postReserve", postReserve);
        emit log_named_uint("postSupply", postSupply);

        assertEqTol(postJuniorTokenPrice, preJuniorTokenPrice, " token price"); // less than the stake was slashed, so the TIN token price shouldn't be impacted
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