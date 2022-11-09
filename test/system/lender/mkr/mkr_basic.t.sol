// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../../test_suite.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "test/lender/coordinator-base.t.sol";
import {Assessor} from "src/lender/assessor.sol";

contract MKRTestBasis is TestSuite, Interest {
    Assessor mkrAssessor;

    function setUp() public {
        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);

        bool mkrAdapter = true;
        TinlakeConfig memory defaultConfig = defaultConfig();
        deployContracts(mkrAdapter, defaultConfig);
        createTestUsers();

        navFeed_ = NAVFeedLike(address(nftFeed));
        root.relyContract(address(clerk), address(this));
        mkrAssessor = assessor;
        mkr.depend("currency", currency_);
        mkr.depend("drop", lenderDeployer.seniorToken());
    }

    // setup a running pool with default values
    function _setupRunningPool() internal {
        uint256 seniorSupplyAmount = 1500 ether;
        uint256 juniorSupplyAmount = 200 ether;
        uint256 nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint256 borrowAmount = 100 ether;
        uint256 maturityDate = 5 days;

        ModelInput memory submission =
            ModelInput({seniorSupply: 800 ether, juniorSupply: 200 ether, seniorRedeem: 0 ether, juniorRedeem: 0 ether});

        supplyAndBorrowFirstLoan(
            seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission
        );
    }

    // invests juniorToken into Tinlake and raises for MKR
    function _setUpMKRLine(uint256 juniorAmount, uint256 mkrAmount) internal {
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

    function _setUpDraw(uint256 mkrAmount, uint256 juniorAmount, uint256 borrowAmount) public {
        _setUpMKRLine(juniorAmount, mkrAmount);
        setupOngoingDefaultLoan(borrowAmount);
        assertEq(currency.balanceOf(address(borrower)), borrowAmount, " _setUpDraw#1");
        uint256 debt = 0;
        if (borrowAmount > juniorAmount) {
            debt = safeSub(borrowAmount, juniorAmount);
        }

        assertEq(clerk.debt(), debt);

        // seniorDebt should equal to seniorRatio from the current NAV
        assertEq(assessor.seniorDebt(), rmul(nftFeed.currentNAV(), assessor.seniorRatio()));
        // check if seniorRatio is correct
        assertEq(
            assessor.seniorRatio(),
            rdiv(
                safeAdd(assessor.seniorDebt(), assessor.effectiveSeniorBalance()),
                safeAdd(nftFeed.currentNAV(), reserve.totalBalance())
            )
        );
    }

    function _setUpOngoingMKR() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        assertEq(clerk.remainingCredit(), 400 ether);
    }

    function _mkrLiquidationPostAssertions() public {
        //sanity check - correct currency amount for each token
        assertEqTol(
            mkrAssessor.getNAV() + reserve.totalBalance(),
            rmul(seniorToken.totalSupply(), mkrAssessor.calcSeniorTokenPrice())
                + rmul(juniorToken.totalSupply(), mkrAssessor.calcJuniorTokenPrice()),
            "mkrPostCon#1"
        );

        assertEqTol(clerk.remainingCredit(), 0, "mkrPostCon#2");
        assertEqTol(clerk.juniorStake(), 0, "mkrPostCon#3");
    }
}

contract MKRBasicSystemTest is MKRTestBasis {
    function testMKRRaise() public {
        _setupRunningPool();
        uint256 preReserve = assessor.totalBalance();
        uint256 preSeniorBalance = assessor.seniorBalance();

        uint256 amountDAI = 10 ether;

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
        uint256 preReserve = assessor.totalBalance();
        uint256 preSeniorBalance = assessor.seniorBalance();

        uint256 creditLineAmount = 10 ether;
        uint256 drawAmount = 5 ether;
        clerk.raise(creditLineAmount);

        //raise reserves a spot for drop and locks the tin
        assertEq(assessor.seniorBalance(), safeAdd(preSeniorBalance, rmul(creditLineAmount, clerk.mat())));
        assertEq(assessor.totalBalance(), safeAdd(preReserve, creditLineAmount));

        uint256 preSeniorDebt = assessor.seniorDebt();
        uint256 preNAV = nftFeed.currentNAV();
        clerk.draw(drawAmount);

        // seniorBalance and reserve should have changed
        assertEq(mkrAssessor.effectiveTotalBalance(), safeAdd(preReserve, drawAmount));

        assertEq(
            safeAdd(mkrAssessor.effectiveSeniorBalance(), assessor.seniorDebt()),
            safeAdd(safeAdd(preSeniorBalance, rmul(drawAmount, clerk.mat())), preSeniorDebt)
        );

        //raise reserves a spot for drop and locks the tin. no impact from the draw function
        assertEq(
            safeAdd(assessor.seniorBalance(), assessor.seniorDebt()),
            safeAdd(safeAdd(preSeniorBalance, rmul(creditLineAmount, clerk.mat())), preSeniorDebt)
        );

        assertEq(assessor.totalBalance(), safeAdd(preReserve, creditLineAmount));

        // seniorDebt should equal to seniorRatio from the current NAV
        assertEq(assessor.seniorDebt(), rmul(nftFeed.currentNAV(), assessor.seniorRatio()));
        // check if seniorRatio is correct after maker draw
        assertEq(
            assessor.seniorRatio(),
            rdiv(
                safeAdd(assessor.seniorDebt(), assessor.effectiveSeniorBalance()),
                safeAdd(safeAdd(preNAV, preReserve), drawAmount)
            )
        );
    }

    function testOnDemandDraw() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
    }

    function testMKRSink() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        uint256 sinkAmount = 50 ether;
        uint256 totalBalance = mkrAssessor.totalBalance();
        uint256 seniorBalance = mkrAssessor.seniorBalance();

        clerk.sink(sinkAmount);
        assertEq(mkrAssessor.totalBalance() + sinkAmount, totalBalance);
        assertEq(mkrAssessor.seniorBalance() + rmul(sinkAmount, clerk.mat()), seniorBalance);
    }

    function testFailMKRSinkTooHigh() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        uint256 sinkAmount = 401 ether;
        clerk.sink(sinkAmount);
    }

    function testMKRSinkAfterRaise() public {
        uint256 mkrAmount = 500 ether;
        uint256 juniorAmount = 200 ether;
        _setUpMKRLine(juniorAmount, mkrAmount);
        clerk.sink(mkrAmount);
    }

    function testRedeemCurrencyFromMKR() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        juniorInvestor.disburse();

        uint256 redeemTokenAmount = 20 ether;
        juniorInvestor.redeemOrder(redeemTokenAmount);
        hevm.warp(block.timestamp + 1 days);
        // currency should come from MKR
        assertEq(reserve.totalBalance(), 0);
        coordinator.closeEpoch();
        (uint256 payoutCurrency,,,) = juniorInvestor.disburse();
        // juniorTokenPrice should be still ONE
        assertEq(currency.balanceOf(address(juniorInvestor)), payoutCurrency);
    }

    function testRedeemWhenExtraCurrencyWasTransferred() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        // mint currency to the reserve, so balanceOf(pot) becomes larger than the balance_ value
        currency.mint(address(this), 1);

        juniorInvestor.disburse();

        uint256 redeemTokenAmount = 20 ether;
        juniorInvestor.redeemOrder(redeemTokenAmount);
        hevm.warp(block.timestamp + 1 days);

        // the redemption order should cause a payout in the reserve, which should work even if
        // additional currency was transferred into the reserve
        coordinator.closeEpoch();
    }

    function testRepayCurrencyToMKR() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        juniorInvestor.disburse();

        uint256 currencyAmount = 50 ether;
        seniorSupply(currencyAmount);
        // seniorInvestor.supplyOrder(currencyAmount);
        hevm.warp(block.timestamp + 1 days);
        // currency should come from MKR
        assertEq(reserve.totalBalance(), 0);
        uint256 preDebt = clerk.debt();
        coordinator.closeEpoch();
        uint256 debt = clerk.debt();
        assertEq(debt, preDebt - currencyAmount);

        assertEq(currency.balanceOf(address(seniorInvestor)), 0);
    }

    function testRepayWhenExtraCurrencyWasTransferred() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        // mint currency to the reserve, so balanceOf(pot) becomes larger than the balance_ value
        currency.mint(address(this), 1);

        juniorInvestor.disburse();

        uint256 currencyAmount = 50 ether;
        seniorSupply(currencyAmount);
        hevm.warp(block.timestamp + 1 days);

        // the supply order should cause a deposit in the reserve, which should work even if
        // additional currency was transferred into the reserve
        coordinator.closeEpoch();
    }

    function testTotalBalanceBuffer() public {
        uint256 fee = 1000000564701133626865910626; // 5% per day
        mkr.file("stabilityFee", fee);
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(block.timestamp + 1 days);

        uint256 debt = clerk.debt();
        uint256 buffer = safeSub(
            rmul(
                rpow(
                    clerk.stabilityFee(),
                    safeSub(safeAdd(block.timestamp, mkrAssessor.creditBufferTime()), block.timestamp),
                    ONE
                ),
                debt
            ),
            debt
        );

        uint256 remainingCredit = clerk.remainingCredit();
        assertEq(assessor.totalBalance(), safeSub(remainingCredit, buffer));
    }

    function testRebalancingInbetweenTrancheEpochUpdates() public {
        // make sure there's some maker debt
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        juniorInvestor.disburse();
        hevm.warp(block.timestamp + 1 days);

        assertEq(clerk.debt(), 100 ether);

        // submit drop invest and tin redeem
        seniorSupply(30 ether);
        juniorInvestor.redeemOrder(5 ether);

        // atempt to close epoch. the drop invest should wipe some of the maker debt, but this causes the senior ratio to become incorrect
        // if there's no rebalancing, the tin redeem will then trigger a draw(), which will notice a collateral deficit
        bool closeWithExecute = true;
        closeEpoch(closeWithExecute);
    }
}
