// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "tinlake-math/interest.sol";
import {BaseTypes} from "test/lender/coordinator-base.t.sol";

import "../test_suite.sol";

contract LenderSystemTest is TestSuite, Interest {
    function setUp() public {
        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);

        baseSetup();
        createTestUsers();
        navFeed_ = NAVFeedLike(address(nftFeed));
    }

    function testSupplyClose() public {
        uint256 seniorSupplyAmount = 82 ether;
        uint256 juniorSupplyAmount = 18 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(block.timestamp + 1 days);

        closeEpoch(true);
    }

    function testSupplyAndBorrow() public {
        uint256 seniorSupplyAmount = 500 ether;
        uint256 juniorSupplyAmount = 20 ether;
        uint256 nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint256 borrowAmount = 100 ether;
        uint256 maturityDate = 5 days;

        ModelInput memory submission =
            ModelInput({seniorSupply: 82 ether, juniorSupply: 18 ether, seniorRedeem: 0 ether, juniorRedeem: 0 ether});

        (uint256 loan,) = supplyAndBorrowFirstLoan(
            seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission
        );
        uint256 nav = nftFeed.calcUpdateNAV();
        assertEq(nav, 100 ether);
    }

    function calcInterest(uint256 amount, uint256 time, uint256 ratePerSecond) public pure returns (uint256) {
        return rmul(rpow(ratePerSecond, time, ONE), amount);
    }

    function testLenderScenarioA() public {
        uint256 seniorSupplyAmount = 500 ether;
        uint256 juniorSupplyAmount = 20 ether;
        uint256 nftPrice = 200 ether;
        uint256 borrowAmount = 100 ether;
        // interest rate default => 5% per day
        uint256 maturityDate = 5 days;

        ModelInput memory submission =
            ModelInput({seniorSupply: 82 ether, juniorSupply: 18 ether, seniorRedeem: 0 ether, juniorRedeem: 0 ether});

        supplyAndBorrowFirstLoan(
            seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission
        );

        uint256 preNAV = nftFeed.calcUpdateNAV();

        assertEq(
            assessor.seniorRatio(),
            rdiv(safeAdd(assessor.seniorBalance_(), assessor.seniorDebt()), safeAdd(preNAV, reserve.totalBalance()))
        );

        assertEq(
            assessor.seniorRatio(),
            rdiv(safeAdd(assessor.seniorBalance_(), assessor.seniorDebt()), safeAdd(preNAV, reserve.totalBalance()))
        );

        // time impact on token senior token price
        hevm.warp(block.timestamp + 1 days);

        uint256 nav = nftFeed.calcUpdateNAV();

        // additional senior debt increase for one day
        assertEq(
            assessor.seniorDebt(),
            calcInterest(rmul(preNAV, assessor.seniorRatio()), 24 hours, assessor.seniorInterestRate())
        );

        assertEq(nav, 105 ether, TWO_DECIMAL_PRECISION);

        // should be 83.64/82 = 83.64/82= 1.02
        uint256 seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 0);
        assertEq(seniorTokenPrice, fixed18To27(1.02 ether), FIXED27_TWO_DECIMAL_PRECISION);

        // new orders
        // first investors need to disburse
        seniorSupplyAmount = 80 ether;
        juniorSupplyAmount = 20 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        // minimum epoch should be already reached
        coordinator.closeEpoch();
        // epoch should be executed no submission required
        assertTrue(coordinator.submissionPeriod() == false);

        // seniorSupply and juniorSupply should be now in reserve
        assertEq(reserve.totalBalance(), 100 ether);

        // nav should be still the same
        nav = nftFeed.calcUpdateNAV();

        // seniorAsset: seniorDebt + seniorBalance =  83.64 + 80 ~ 163.64
        // NAV + reserve ~ 205
        // seniorRatio: 163.64/205 ~ 0.79
        uint256 shouldSeniorRatio = rdiv(assessor.seniorDebt() + assessor.seniorBalance(), nav + reserve.totalBalance());

        assertEq(coordinator.epochNAV(), nav, TWO_DECIMAL_PRECISION);
        assertEq(coordinator.epochSeniorAsset(), 83.64 ether, TWO_DECIMAL_PRECISION);
        assertEq(assessor.seniorRatio(), shouldSeniorRatio);
        assertEq(assessor.seniorRatio(), fixed18To27(0.79 ether), FIXED27_TWO_DECIMAL_PRECISION);

        // check reBalancing
        assertEq(assessor.seniorDebt(), rmul(nav, shouldSeniorRatio));
        assertEq(
            assessor.seniorBalance(), coordinator.epochSeniorAsset() + seniorSupplyAmount - rmul(nav, shouldSeniorRatio)
        );
    }

    function testAutomaticReSupply() public {
        uint256 seniorSupplyAmount = 1000 ether;
        uint256 juniorSupplyAmount = 20 ether;
        uint256 nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint256 borrowAmount = 100 ether;
        uint256 maturityDate = 5 days;

        ModelInput memory submission =
            ModelInput({seniorSupply: 80 ether, juniorSupply: 20 ether, seniorRedeem: 0 ether, juniorRedeem: 0 ether});

        supplyAndBorrowFirstLoan(
            seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission
        );

        hevm.warp(block.timestamp + 1 days);
        juniorSupplyAmount = 180 ether;

        juniorSupply(juniorSupplyAmount);

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        assertEq(seniorToken.balanceOf(seniorInvestor_), 80 ether);
        // senior

        (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        ) = seniorTranche.calcDisburse(seniorInvestor_);

        assertEq(payoutTokenAmount, seniorToken.balanceOf(address(seniorTranche)));
        assertEq(remainingSupplyCurrency, 0);

        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            seniorInvestor.disburse();

        // 80 ether token from previous supply/redeem
        assertEq(seniorToken.balanceOf(seniorInvestor_), safeAdd(payoutTokenAmount, 80 ether));

        uint256 seniorTokenPrice = assessor.calcSeniorTokenPrice(nftFeed.latestNAV(), reserve.totalBalance());
        uint256 juniorTokenPrice = assessor.calcJuniorTokenPrice(nftFeed.latestNAV(), reserve.totalBalance());

        // ongoing loan has 5 % interest, senior wants 2% interest therefore 3%  left for junior
        // juniorAssetValue increased more than seniorAssetValue therefore higher juniorTokenPrice
        assertTrue(juniorTokenPrice > seniorTokenPrice);

        assertEq(
            nftFeed.latestNAV() + reserve.totalBalance(),
            rmul(seniorTranche.tokenSupply(), seniorTokenPrice) + rmul(juniorTranche.tokenSupply(), juniorTokenPrice),
            10
        );
    }

    function testLoanRepayments() public {
        uint256 seniorSupplyAmount = 1000 ether;
        uint256 juniorSupplyAmount = 20 ether;
        uint256 nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint256 borrowAmount = 100 ether;
        uint256 maturityDate = 5 days;

        ModelInput memory submission =
            ModelInput({seniorSupply: 80 ether, juniorSupply: 20 ether, seniorRedeem: 0 ether, juniorRedeem: 0 ether});

        (uint256 loan,) = supplyAndBorrowFirstLoan(
            seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission
        );

        // remove existing order
        seniorSupply(0);

        hevm.warp(block.timestamp + 1 days);

        uint256 nav = nftFeed.calcUpdateNAV();

        assertEq(nav, 105 ether, TWO_DECIMAL_PRECISION);

        assertEq(reserve.totalBalance(), 0);

        uint256 loanDebt = pile.debt(loan);
        repayLoan(address(borrower), loan, loanDebt);

        assertEq(reserve.totalBalance(), loanDebt);
        assertEq(nftFeed.latestNAV(), 0);

        // max redeem from both
        seniorInvestor.redeemOrder(seniorToken.balanceOf(seniorInvestor_));
        juniorInvestor.redeemOrder(juniorToken.balanceOf(juniorInvestor_));

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        // senior full payout
        (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        ) = seniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, rmul(80 ether, coordinator.epochSeniorTokenPrice()));

        // junior full payout
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            juniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, rmul(20 ether, coordinator.epochJuniorTokenPrice()));
    }

    function juniorWithLosses() public returns (uint256 loan, uint256 tokenId) {
        uint256 seniorSupplyAmount = 1000 ether;
        uint256 juniorSupplyAmount = 20 ether;
        uint256 nftPrice = 100 ether;
        // interest rate default => 5% per day
        uint256 borrowAmount = 50 ether;

        ModelInput memory submission =
            ModelInput({seniorSupply: 80 ether, juniorSupply: 20 ether, seniorRedeem: 0 ether, juniorRedeem: 0 ether});

        (loan, tokenId) =
            supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, 5 days, submission);
        (uint256 loan2, uint256 tokenId) = setupOngoingLoan(nftPrice, borrowAmount, false, block.timestamp);
        //        // change senior interest rate
        root.relyContract(address(assessor), address(this));
        // change interest rate to 10% a day
        uint256 highRate = uint256(1000001103100000000000000000);
        assessor.file("seniorInterestRate", highRate);

        // remove existing order
        seniorSupply(0);

        hevm.warp(block.timestamp + 3 days);

        assessor.calcSeniorTokenPrice();

        // senior interest is to high, the ongoing loans have too low returns
        // therefore junior is paying it
        uint256 juniorTokenPrice = assessor.calcJuniorTokenPrice();

        // token price should be below ONE
        assertTrue(juniorTokenPrice < ONE);

        // now ongoing loan is not repaid before maturity date: moved to write-off by admin
        root.relyContract(address(pile), address(this));
        root.relyContract(address(nftFeed), address(this));
        assertEq(nftFeed.currentNAV(), safeAdd(pile.debt(loan), pile.debt(loan2)));
        nftFeed.writeOff(loan2); // writeOff loan -> exclude from nav
        assertEq(nftFeed.currentNAV(), pile.debt(loan));

        assessor.calcUpdateNAV();
        juniorTokenPrice = assessor.calcJuniorTokenPrice();

        assertTrue(assessor.seniorDebt() > nftFeed.currentNAV());

        // junior lost everything
        assertEq(juniorTokenPrice, 0);

        return (loan, tokenId);
    }

    function testJuniorLosses() public {
        // test junior losses
        juniorWithLosses();
    }

    function testDisburseAfterJuniorLost() public {
        // test setup junior lost everything
        (uint256 loan,) = juniorWithLosses();

        emit log_named_uint("price", assessor.calcJuniorTokenPrice());
        // junior lost everything
        assertEq(assessor.calcJuniorTokenPrice(), 0);

        uint256 loanDebt = pile.debt(loan);

        nftFeed.writeOff(loan);
        repayLoan(address(borrower), loan, loanDebt);

        assertEq(reserve.totalBalance(), loanDebt);
        emit log_named_uint("nftFeed.currentNAV()", nftFeed.currentNAV());
        assertEq(nftFeed.currentNAV(), 0, 10);

        uint256 oneWeiLeft = 1;
        // max redeem from both
        seniorInvestor.redeemOrder(seniorToken.balanceOf(seniorInvestor_) - oneWeiLeft);
        juniorInvestor.redeemOrder(juniorToken.balanceOf(juniorInvestor_));

        // tokens should be locked
        assertEq(seniorToken.balanceOf(seniorInvestor_), oneWeiLeft);
        assertEq(juniorToken.balanceOf(juniorInvestor_), 0);

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        // senior full payout
        (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        ) = seniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, rmul(80 ether - oneWeiLeft, coordinator.epochSeniorTokenPrice()));
        assertEq(remainingRedeemToken, 0);
        assertEq(remainingSupplyCurrency, 0);

        // junior payout
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            juniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, 0);
        assertEq(remainingSupplyCurrency, 0);
        // junior tokens can't be removed and are still locked
        assertEq(remainingRedeemToken, 20 ether);

        // get worthless tokens back via order change
        juniorInvestor.redeemOrder(0);
        assertEq(juniorToken.balanceOf(juniorInvestor_), 20 ether);
    }

    function testPoolClosingScenarioB() public {
        Investor seniorInvestorB =
            new Investor(address(seniorOperator), address(seniorTranche), currency_, address(seniorToken));
        uint256 seniorAmount = 40 ether;

        // two senior investors
        seniorSupply(seniorAmount, seniorInvestor);
        seniorSupply(seniorAmount, seniorInvestorB);

        // one junior investor
        juniorSupply(20 ether);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        // borrow loans maturity date 5 days from now
        uint256 borrowAmount = 100 ether;
        uint256 nftPrice = 200 ether;
        uint256 maturityDate = 5 days;
        (uint256 loan,) = setupOngoingLoan(nftPrice, borrowAmount, false, block.timestamp + maturityDate);
        uint256 highRate = uint256(1000001103100000000000000000);
        root.relyContract(address(assessor), address(this));
        assessor.file("seniorInterestRate", highRate);

        // loan not repaid and written off by 75%
        hevm.warp(block.timestamp + 10 days);
        root.relyContract(address(nftFeed), address(this));

        // junior should lost everything
        assertTrue(assessor.seniorDebt() > nftFeed.currentNAV());

        // repay loan to get some currency in reserve
        uint256 loanDebt = pile.debt(loan);
        repayLoan(address(borrower), loan, loanDebt);

        // get tokens
        seniorInvestor.disburse();
        seniorInvestorB.disburse();

        // only one investor wants to redeem
        seniorInvestor.redeemOrder(seniorAmount);

        coordinator.closeEpoch();
        assertTrue(coordinator.poolClosing() == true);

        assertTrue(coordinator.submissionPeriod() == false);

        (uint256 payoutCurrencyAmount,,, uint256 remainingRedeemToken) = seniorInvestor.disburse();
        assertTrue(payoutCurrencyAmount > 0);
        assertEq(remainingRedeemToken, 0);
    }

    function testCloseEpochNoOrders() public {
        seniorSupply(80 ether, seniorInvestor);
        // one junior investor
        juniorSupply(20 ether);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        // borrow loans maturity date 5 days from now
        uint256 borrowAmount = 100 ether;
        uint256 nftPrice = 200 ether;
        uint256 maturityDate = 5 days;
        setupOngoingLoan(nftPrice, borrowAmount, false, block.timestamp + maturityDate);

        hevm.warp(block.timestamp + 1 days);

        // no orders - close epoch
        coordinator.closeEpoch();

        // 100% of currency borrowed => seniorRatio = curr. SeniorDebt/curr NAV
        assertEq(
            assessor.seniorRatio(), rdiv(assessor.seniorDebt(), assessor.calcUpdateNAV()), FIXED27_TEN_DECIMAL_PRECISION
        );
    }

    function testCloseEpochNoOrdersReserveUpdate() public {
        // supply currency
        seniorSupply(80 ether, seniorInvestor);
        juniorSupply(20 ether);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        // borrow loans maturity date 5 days from now
        uint256 borrowAmount = 100 ether;
        uint256 nftPrice = 200 ether;
        uint256 maturityDate = 5 days;
        (uint256 loan,) = setupOngoingLoan(nftPrice, borrowAmount, false, block.timestamp + maturityDate);

        hevm.warp(block.timestamp + 1 days);

        uint256 repayAmount = 60 ether;
        repayLoan(address(borrower), loan, repayAmount);

        assertEq(reserve.currencyAvailable(), 0);
        coordinator.closeEpoch();
        // repaid amount should be available for new loans after epoch is closed
        assertEq(reserve.currencyAvailable(), repayAmount);
    }

    function testRedeemFinancedWithInvestments() public {
        uint256 seniorSupplyAmount = 840 ether;
        uint256 juniorSupplyAmount = 1000 ether;
        uint256 nftPrice = 2000 ether;
        // interest rate default => 5% per day
        uint256 borrowAmount = 1000 ether;
        uint256 maturityDate = 5 days;

        ModelInput memory submission =
            ModelInput({seniorSupply: 840 ether, juniorSupply: 160 ether, seniorRedeem: 0 ether, juniorRedeem: 0 ether});

        supplyAndBorrowFirstLoan(
            seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission
        );

        // test case scenario
        // reserve: 0
        // seniorRedeem: 1 ether
        // juniorInvest: 1 ether
        assertEq(reserve.totalBalance(), 0);
        juniorSupply(1 ether);
        seniorInvestor.redeemOrder(1.5 ether);

        hevm.warp(block.timestamp + 1 days);

        coordinator.closeEpoch();
        submission =
            ModelInput({seniorSupply: 0 ether, juniorSupply: 1 ether, seniorRedeem: 1 ether, juniorRedeem: 0 ether});

        int256 valid = submitSolution(address(coordinator), submission);
        assertEq(valid, coordinator.NEW_BEST());

        hevm.warp(block.timestamp + 2 hours);

        coordinator.executeEpoch();

        uint256 preBalance = currency.balanceOf(seniorInvestor_);

        (uint256 payoutCurrencyAmount,,,) = juniorInvestor.disburse();

        assertEq(currency.balanceOf(seniorInvestor_), safeAdd(preBalance, payoutCurrencyAmount));
        assertEq(seniorTranche.requestedCurrency(), 0);
    }
}
