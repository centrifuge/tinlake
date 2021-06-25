// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "../../test_suite.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "../../../../lender/test/coordinator-base.t.sol";
import { Assessor }from "../../../../lender/assessor.sol";

contract MKRTestBasis is TestSuite, Interest {
    Assessor mkrAssessor;

    function setUp() public {
        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);

        bool mkrAdapter = true;
        TinlakeConfig memory defaultConfig = defaultConfig();
        deployContracts(mkrAdapter, defaultConfig);
        createTestUsers(); 

        nftFeed_ = NFTFeedLike(address(nftFeed));
        root.relyContract(address(clerk), address(this));
        mkrAssessor = assessor;
        mkr.depend("currency" ,currency_);
        mkr.depend("drop", lenderDeployer.seniorToken());
    }


    // setup a running pool with default values
    function _setupRunningPool() internal {
        uint seniorSupplyAmount = 1500 ether;
        uint juniorSupplyAmount = 200 ether;
        uint nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 800 ether,
            juniorSupply : 200 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);
    }

    // invests juniorToken into Tinlake and raises for MKR
    function _setUpMKRLine(uint juniorAmount, uint mkrAmount) internal {
        root.relyContract(address(reserve), address(this));

        root.relyContract(address(mkrAssessor), address(this));
        mkrAssessor.file("minSeniorRatio", 0);

        // activate clerk in reserve
        reserve.depend("lending", address(clerk));

        juniorSupply(juniorAmount);

        hevm.warp(block.timestamp + 1 days);

        bool closeWithExecute = true;
        closeEpoch(closeWithExecute);
        assertTrue(coordinator.submissionPeriod() == false);

        clerk.raise(mkrAmount);
        assertEq(clerk.remainingCredit(), mkrAmount);
    }

    function _setUpDraw(uint mkrAmount, uint juniorAmount, uint borrowAmount) public {
        _setUpMKRLine(juniorAmount, mkrAmount);
        setupOngoingDefaultLoan(borrowAmount);
        assertEq(currency.balanceOf(address(borrower)), borrowAmount, " _setUpDraw#1");
        uint debt = 0;
        if(borrowAmount > juniorAmount) {
            debt = safeSub(borrowAmount, juniorAmount);
        }
        assertEq(clerk.debt(), debt);
    }

    function _setUpOngoingMKR() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        assertEq(clerk.remainingCredit(), 400 ether);
    }

    function _mkrLiquidationPostAssertions() public {
        //sanity check - correct currency amount for each token
        assertEqTol(mkrAssessor.currentNAV() + reserve.totalBalance(), rmul(seniorToken.totalSupply(), mkrAssessor.calcSeniorTokenPrice())
            + rmul(juniorToken.totalSupply(), mkrAssessor.calcJuniorTokenPrice()),  "mkrPostCon#1");

        assertEqTol(clerk.remainingCredit(), 0,  "mkrPostCon#2");
        assertEqTol(clerk.juniorStake(), 0,  "mkrPostCon#3");
    }
}


contract MKRBasicSystemTest is MKRTestBasis {

    function testMKRRaise() public {
        _setupRunningPool();
        uint preReserve = assessor.totalBalance();
        uint preSeniorBalance = assessor.seniorBalance();

        uint amountDAI = 10 ether;

        clerk.raise(amountDAI);

        //raise reserves a spot for drop and locks the tin
        assertEq(assessor.seniorBalance(), safeAdd(preSeniorBalance, rmul(amountDAI, clerk.mat())));
        assertEq(assessor.totalBalance(), safeAdd(preReserve, amountDAI));

        assertEq(mkrAssessor.effectiveTotalBalance(), preReserve);
        assertEq(mkrAssessor.effectiveSeniorBalance(), preSeniorBalance);
        assertEq(clerk.remainingCredit(), amountDAI);
    }

    function testMKRDraw() public {
        _setupRunningPool();
        uint preReserve = assessor.totalBalance();
        uint preSeniorBalance = assessor.seniorBalance();

        uint creditLineAmount = 10 ether;
        uint drawAmount = 5 ether;
        clerk.raise(creditLineAmount);

        //raise reserves a spot for drop and locks the tin
        assertEq(assessor.seniorBalance(), safeAdd(preSeniorBalance, rmul(creditLineAmount, clerk.mat())));
        assertEq(assessor.totalBalance(), safeAdd(preReserve, creditLineAmount));

        uint preSeniorDebt = assessor.seniorDebt();
        clerk.draw(drawAmount);

        // seniorBalance and reserve should have changed
        assertEq(mkrAssessor.effectiveTotalBalance(), safeAdd(preReserve, drawAmount));

        assertEq(safeAdd(mkrAssessor.effectiveSeniorBalance(),assessor.seniorDebt()),
            safeAdd(safeAdd(preSeniorBalance, rmul(drawAmount, clerk.mat())), preSeniorDebt));

        //raise reserves a spot for drop and locks the tin. no impact from the draw function
        assertEq(safeAdd(assessor.seniorBalance(),assessor.seniorDebt()),
            safeAdd(safeAdd(preSeniorBalance, rmul(creditLineAmount, clerk.mat())), preSeniorDebt));

        assertEq(assessor.totalBalance(), safeAdd(preReserve, creditLineAmount));
    }

    function testOnDemandDraw() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
    }

    function testMKRSink() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        uint sinkAmount = 50 ether;
        uint totalBalance = mkrAssessor.totalBalance();
        uint seniorBalance = mkrAssessor.seniorBalance();

        clerk.sink(sinkAmount);
        assertEq(mkrAssessor.totalBalance()+sinkAmount, totalBalance);
        assertEq(mkrAssessor.seniorBalance()+rmul(sinkAmount, clerk.mat()), seniorBalance);
    }

    function testFailMKRSinkTooHigh() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        uint sinkAmount = 401 ether;
        clerk.sink(sinkAmount);
    }

    function testMKRSinkAfterRaise() public {
        uint mkrAmount = 500 ether;
        uint juniorAmount = 200 ether;
        _setUpMKRLine(juniorAmount, mkrAmount);
       clerk.sink(mkrAmount);
    }

    function testRedeemCurrencyFromMKR() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        juniorInvestor.disburse();

        uint redeemTokenAmount = 20 ether;
        juniorInvestor.redeemOrder(redeemTokenAmount);
        hevm.warp(block.timestamp + 1 days);
        // currency should come from MKR
        assertEq(reserve.totalBalance(), 0);
        coordinator.closeEpoch();
        (uint payoutCurrency,,,) = juniorInvestor.disburse();
        // juniorTokenPrice should be still ONE
        assertEq(currency.balanceOf(address(juniorInvestor)), payoutCurrency);
    }

    function testRepayCurrencyToMKR() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        juniorInvestor.disburse();

        uint currencyAmount = 50 ether;
        seniorSupply(currencyAmount);
        // seniorInvestor.supplyOrder(currencyAmount);
        hevm.warp(block.timestamp + 1 days);
        // currency should come from MKR
        assertEq(reserve.totalBalance(), 0);
        uint preDebt = clerk.debt();
        coordinator.closeEpoch();
        uint debt = clerk.debt();
        assertEq(debt, preDebt - currencyAmount);

        assertEq(currency.balanceOf(address(seniorInvestor)), 0);
    }


    function testTotalBalanceBuffer() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(block.timestamp + 1 days);

        uint debt = clerk.debt();
        uint buffer = safeSub(rmul(rpow(clerk.stabilityFee(),
            safeSub(safeAdd(block.timestamp, mkrAssessor.creditBufferTime()), block.timestamp), ONE), debt), debt);

        uint remainingCredit = clerk.remainingCredit();
        assertEq(assessor.totalBalance(), safeSub(remainingCredit, buffer));
    }

}
