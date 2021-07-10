// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;


import "tinlake-math/interest.sol";
import {BaseTypes} from "../../../lender/test/coordinator-base.t.sol";

import "../test_suite.sol";

contract LenderSystemTest is TestSuite, Interest {

    function setUp() public {
        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);

        baseSetup();
        createTestUsers();
        nftFeed_ = NFTFeedLike(address(nftFeed));

    }

    function testSupplyClose() public {
        uint seniorSupplyAmount = 82 ether;
        uint juniorSupplyAmount = 18 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(block.timestamp + 1 days);

        closeEpoch(true);
    }

    function testSupplyAndBorrow() public {
        uint seniorSupplyAmount = 500 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 82 ether,
            juniorSupply : 18 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        (uint loan, ) = supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);
        uint nav = nftFeed.calcUpdateNAV();
        uint fv = nftFeed.futureValue(nftFeed.nftID(loan));

        // FV = 100 * 1.05^5 = 127.62815625
        assertEq(fv, 127.62815625 ether);

        // (FV/1.03^5) = 110.093;
        assertEq(nav, 110.093921369062927876 ether);

    }

    function calcInterest(uint amount, uint time, uint ratePerSecond)   public pure returns(uint) {
        return rmul(rpow(ratePerSecond, time, ONE), amount);
    }

    function testLenderScenarioA() public {
        uint seniorSupplyAmount = 500 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;


        ModelInput memory submission = ModelInput({
            seniorSupply : 82 ether,
            juniorSupply : 18 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);

        uint preNAV = nftFeed.calcUpdateNAV();

        assertEq(assessor.seniorRatio(), rdiv(safeAdd(assessor.seniorBalance_(), assessor.seniorDebt())
        , safeAdd(preNAV, reserve.totalBalance())));

        assertEq(assessor.seniorRatio(), rdiv(safeAdd(assessor.seniorBalance_(), assessor.seniorDebt())
        , safeAdd(preNAV, reserve.totalBalance())));

        // time impact on token senior token price
        hevm.warp(block.timestamp + 1 days);

        uint nav = nftFeed.calcUpdateNAV();

        // additional senior debt increase for one day
        assertEq(assessor.seniorDebt(), calcInterest(rmul(preNAV, assessor.seniorRatio()), 24 hours, assessor.seniorInterestRate()));


        //(FV/1.03^4) = 127.62815625 /(1.03^4) = 113.395963777
        assertEq(nav, 113.39 ether, TWO_DECIMAL_PRECISION);

        // should be 83.64/82 = 83.64/82= 1.02
        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 0);
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
         preNAV = nftFeed.calcUpdateNAV();
         nav = nftFeed.calcUpdateNAV();

        // nav= 113.39 ether
        assertEq(nav, preNAV);

        // seniorAsset: seniorDebt + seniorBalance =  83.64 + 80 ~ 163.64
        // NAV + reserve ~ 213.39
        // seniorRatio: 163.64/213.139 ~ 0.76
        uint shouldSeniorRatio = rdiv(assessor.seniorDebt() + assessor.seniorBalance(), nav + reserve.totalBalance());

        assertEq(coordinator.epochNAV(), nav, TWO_DECIMAL_PRECISION);
        assertEq(coordinator.epochSeniorAsset(), 83.64 ether, TWO_DECIMAL_PRECISION);
        assertEq(assessor.seniorRatio(), shouldSeniorRatio);
        assertEq(assessor.seniorRatio(), fixed18To27(0.76 ether), FIXED27_TWO_DECIMAL_PRECISION);

        // check reBalancing
        assertEq(assessor.seniorDebt(), rmul(nav, shouldSeniorRatio));
        assertEq(assessor.seniorBalance(), coordinator.epochSeniorAsset()+seniorSupplyAmount - rmul(nav, shouldSeniorRatio));
    }

    function testAutomaticReSupply() public {
        uint seniorSupplyAmount = 1000 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 100 ether;
        uint maturityDate =  5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 80 ether,
            juniorSupply : 20 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate,  submission);

        hevm.warp(block.timestamp + 1 days);
        juniorSupplyAmount = 180 ether;

        juniorSupply(juniorSupplyAmount);

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

         assertEq(seniorToken.balanceOf(seniorInvestor_), 80 ether);
        // senior

        (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) = seniorTranche.calcDisburse(seniorInvestor_);

        assertEq(payoutTokenAmount, seniorToken.balanceOf(address(seniorTranche)));
        assertEq(remainingSupplyCurrency, 0);

        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) = seniorInvestor.disburse();

        // 80 ether token from previous supply/redeem
        assertEq(seniorToken.balanceOf(seniorInvestor_), safeAdd(payoutTokenAmount, 80 ether));

        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nftFeed.approximatedNAV(), reserve.totalBalance());
        uint juniorTokenPrice = assessor.calcJuniorTokenPrice(nftFeed.approximatedNAV(), reserve.totalBalance());

        // ongoing loan has 5 % interest, senior wants 2% interest therefore 3%  left for junior
        // juniorAssetValue increased more than seniorAssetValue therefore higher juniorTokenPrice
        assertTrue(juniorTokenPrice > seniorTokenPrice);

        assertEq(nftFeed.approximatedNAV() + reserve.totalBalance(), rmul(seniorTranche.tokenSupply(),seniorTokenPrice) + rmul(juniorTranche.tokenSupply(),juniorTokenPrice), 10);
    }

    function testLoanRepayments() public {
        uint seniorSupplyAmount = 1000 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 80 ether,
            juniorSupply : 20 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        (uint loan,  ) = supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);

        // remove existing order
        seniorSupply(0);

        hevm.warp(block.timestamp + 1 days);

        uint nav = nftFeed.calcUpdateNAV();

        //(FV/1.03^4) = 127.62815625 /(1.03^4) = 113.395963777
        assertEq(nav, 113.39 ether, TWO_DECIMAL_PRECISION);

        assertEq(reserve.totalBalance(), 0);

        uint loanDebt = pile.debt(loan);
        repayLoan(address(borrower), loan, loanDebt);

        assertEq(reserve.totalBalance(), loanDebt);
        assertEq(nftFeed.approximatedNAV(), 0);

        // max redeem from both
        seniorInvestor.redeemOrder(seniorToken.balanceOf(seniorInvestor_));
        juniorInvestor.redeemOrder(juniorToken.balanceOf(juniorInvestor_));

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        // senior full payout
        (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) = seniorInvestor.disburse();
        assertEq(payoutCurrencyAmount ,rmul(80 ether, coordinator.epochSeniorTokenPrice()));

        // junior full payout
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) = juniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, rmul(20 ether, coordinator.epochJuniorTokenPrice()));
    }

    function juniorWithLosses() public returns (uint loan, uint tokenId) {
        uint seniorSupplyAmount = 1000 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 100 ether;

        ModelInput memory submission = ModelInput({
            seniorSupply : 80 ether,
            juniorSupply : 20 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        // maturity date 5 days
        (loan, tokenId) = supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, 5 days, submission);
        //        // change senior interest rate
        root.relyContract(address(assessor), address(this));
        // change interest rate to 10% a day
        uint highRate = uint(1000001103100000000000000000);
        assessor.file("seniorInterestRate", highRate);


        // remove existing order
        seniorSupply(0);

        hevm.warp(block.timestamp + 3 days);

        assessor.calcSeniorTokenPrice();

        // senior interest is to high, the ongoing loans have too low returns
        // therefore junior is paying it
        uint juniorTokenPrice = assessor.calcJuniorTokenPrice();

        // token price should be below ONE
        assertTrue(juniorTokenPrice < ONE);

        hevm.warp(block.timestamp + 3 days);

        uint nav = nftFeed.currentNAV();

        // now ongoing loan is not repaid before maturity date: moved to write-off by admin
        assertEq(nav, 0);
        root.relyContract(address(pile), address(this));

        // 40% write off because one day too late
        // increase loan rate from 5% to 6%
        pile.changeRate(loan, nftFeed.WRITE_OFF_PHASE_A());
        emit log_named_uint("loan debt",pile.debt(loan));
        assertEq(nftFeed.currentNAV(), rmul(pile.debt(loan), 6 * 10**26));

        juniorTokenPrice = assessor.calcJuniorTokenPrice();

        // senior debt ~141 ether and nav ~134 ether
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
        (uint loan, ) = juniorWithLosses();

        // junior lost everything
        assertEq(assessor.calcJuniorTokenPrice(), 0);

        uint loanDebt = pile.debt(loan);
        repayLoan(address(borrower), loan, loanDebt);

        assertEq(reserve.totalBalance(), loanDebt);
        assertEq(nftFeed.approximatedNAV(), 0);

        // max redeem from both
        seniorInvestor.redeemOrder(seniorToken.balanceOf(seniorInvestor_));
        juniorInvestor.redeemOrder(juniorToken.balanceOf(juniorInvestor_));

        // tokens should be locked
        assertEq(seniorToken.balanceOf(seniorInvestor_), 0);
        assertEq(juniorToken.balanceOf(juniorInvestor_), 0);

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        // senior full payout
        (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) = seniorInvestor.disburse();
        assertEq(payoutCurrencyAmount ,rmul(80 ether, coordinator.epochSeniorTokenPrice()));
        assertEq(remainingRedeemToken, 0);
        assertEq(remainingSupplyCurrency, 0);

        // junior payout
        (payoutCurrencyAmount,  payoutTokenAmount,  remainingSupplyCurrency,  remainingRedeemToken) = juniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, 0);
        assertEq(remainingSupplyCurrency, 0);
        // junior tokens can't be removed and are still locked
        assertEq(remainingRedeemToken, 20 ether);

        // get worthless tokens back via order change
        juniorInvestor.redeemOrder(0);
        assertEq(juniorToken.balanceOf(juniorInvestor_), 20 ether);
    }

    function testPoolClosingScenarioB() public {
        Investor seniorInvestorB = new Investor(address(seniorOperator), address(seniorTranche), currency_, address(seniorToken));
        uint seniorAmount = 40 ether;

        // two senior investors
        seniorSupply(seniorAmount, seniorInvestor);
        seniorSupply(seniorAmount, seniorInvestorB);

        // one junior investor
        juniorSupply(20 ether);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

        // borrow loans maturity date 5 days from now
        uint borrowAmount = 100 ether;
        uint nftPrice = 200 ether;
        uint maturityDate = 5 days;
        (uint loan, ) = setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(block.timestamp) +maturityDate);
        uint highRate = uint(1000001103100000000000000000);
        root.relyContract(address(assessor), address(this));
        assessor.file("seniorInterestRate", highRate);


        // loan not repaid and not moved to penalty rate
        hevm.warp(block.timestamp + 6 days);

        // junior should lost everything
        assertTrue(assessor.seniorDebt() > nftFeed.currentNAV());

        // repay loan to get some currency in reserve
        uint loanDebt = pile.debt(loan);
        repayLoan(address(borrower), loan, loanDebt);


        // get tokens
        seniorInvestor.disburse();
        seniorInvestorB.disburse();

        // only one investor wants to redeem
        seniorInvestor.redeemOrder(seniorAmount);

        coordinator.closeEpoch();
        assertTrue(coordinator.poolClosing() == true);

        assertTrue(coordinator.submissionPeriod() == false);

        (uint payoutCurrencyAmount, , ,uint remainingRedeemToken)  = seniorInvestor.disburse();
        assertTrue(payoutCurrencyAmount >  0);
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
        uint borrowAmount = 100 ether;
        uint nftPrice = 200 ether;
        uint maturityDate = 5 days;
        setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(block.timestamp) +maturityDate);

        hevm.warp(block.timestamp + 1 days);

        // no orders - close epoch
        coordinator.closeEpoch();

        // 100% of currency borrowed => seniorRatio = curr. SeniorDebt/curr NAV
        assertEq(assessor.seniorRatio(), rdiv(assessor.seniorDebt(), assessor.calcUpdateNAV()), FIXED27_TEN_DECIMAL_PRECISION);
    }


    function testCloseEpochNoOrdersReserveUpdate() public {
        // supply currency
        seniorSupply(80 ether, seniorInvestor);
        juniorSupply(20 ether);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        // borrow loans maturity date 5 days from now
        uint borrowAmount = 100 ether;
        uint nftPrice = 200 ether;
        uint maturityDate = 5 days;
        (uint loan, ) = setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(block.timestamp) + maturityDate);

        hevm.warp(block.timestamp + 1 days);

        uint repayAmount = 60 ether;
        repayLoan(address(borrower), loan, repayAmount);

        assertEq(reserve.currencyAvailable(), 0 );
        coordinator.closeEpoch();
        // repaid amount should be available for new loans after epoch is closed
        assertEq(reserve.currencyAvailable(), repayAmount);
    }

    function testRedeemFinancedWithInvestments() public {
        uint seniorSupplyAmount = 840 ether;
        uint juniorSupplyAmount = 1000 ether;
        uint nftPrice = 2000 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 1000 ether;
        uint maturityDate = 5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 840 ether,
            juniorSupply : 160 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);

        // test case scenario
        // reserve: 0
        // seniorRedeem: 1 ether
        // juniorInvest: 1 ether
        assertEq(reserve.totalBalance(), 0);
        juniorSupply(1 ether);
        seniorInvestor.redeemOrder(1.5 ether);

        hevm.warp(block.timestamp + 1 days);

        coordinator.closeEpoch();
        submission = ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 1 ether,
            seniorRedeem : 1 ether,
            juniorRedeem : 0 ether
            });


        int valid = submitSolution(address(coordinator), submission);
        assertEq(valid, coordinator.NEW_BEST());

        hevm.warp(block.timestamp + 2 hours);

        coordinator.executeEpoch();

        uint preBalance = currency.balanceOf(seniorInvestor_);

        (uint payoutCurrencyAmount,  ,  , ) = juniorInvestor.disburse();

        assertEq(currency.balanceOf(seniorInvestor_), safeAdd(preBalance, payoutCurrencyAmount));
        assertEq(seniorTranche.requestedCurrency(), 0);
    }
 }
