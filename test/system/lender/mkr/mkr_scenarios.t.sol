// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

pragma experimental ABIEncoderV2;

import "../../test_suite.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "test/lender/coordinator-base.t.sol";
import {MKRTestBasis} from "./mkr_basic.t.sol";

contract MKRLenderSystemTest is MKRTestBasis {
    function dripMakerDebt() public {}

    function setStabilityFee(uint256 fee) public {
        mkr.file("stabilityFee", fee);
    }

    function makerEvent(bytes32 name, bool flag) public {
        mkr.file(name, flag);
    }

    function warp(uint256 plusTime) public {
        hevm.warp(block.timestamp + plusTime);
    }

    function testOnDemandDrawWithStabilityFee() public {
        uint256 fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        warp(1 days);
        assertEq(clerk.debt(), 105 ether, "testStabilityFee#2");
    }

    function testMKRWipe() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 500 ether;
        uint256 repayAmount = 100 ether;
        mkrWipe(juniorAmount, mkrAmount, borrowAmount, repayAmount, false);
    }

    function testMKRWipeRepayHigherThanJunior() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 500 ether;
        uint256 repayAmount = 300 ether;
        mkrWipe(juniorAmount, mkrAmount, borrowAmount, repayAmount, true);
    }

    function mkrWipe(
        uint256 juniorAmount,
        uint256 mkrAmount,
        uint256 borrowAmount,
        uint256 repayAmount,
        bool doPreHarvest
    ) public {
        setStabilityFee(uint256(1000000115165872987700711356)); // 1 % day
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        warp(1 days);

        uint256 expectedDebt = 303 ether;
        assertEqTol(clerk.debt(), expectedDebt, "testMKRWipe#1");
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer

        uint256 preLockedDAIHarvest = rmul(clerk.cdpink(), mkrAssessor.calcSeniorTokenPrice());
        uint256 preSeniorAssetHarvest = safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance());

        // harvest before wipe call
        if (doPreHarvest) {
            clerk.harvest();
        }
        uint256 preRequiredLocked = clerk.calcOvercollAmount(clerk.debt());
        uint256 preSeniorAsset = safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance());

        // wipe is triggered by repay
        repayDefaultLoan(repayAmount);

        // reduces clerk debt
        assertEqTol(clerk.debt(), safeSub(expectedDebt, repayAmount), "testMKRWipe#2");
        assertEq(reserve.totalBalance(), 0, "testMKRWipe#3");

        uint256 decreaseSeniorAsset =
            safeSub(preLockedDAIHarvest, rmul(clerk.cdpink(), mkrAssessor.calcSeniorTokenPrice()));
        assertEqTol(
            safeSub(preSeniorAssetHarvest, decreaseSeniorAsset),
            safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance()),
            "testMKRWipe#4"
        );
        if (doPreHarvest) {
            assertEqTol(
                safeSub(preSeniorAsset, safeSub(preRequiredLocked, clerk.calcOvercollAmount(clerk.debt()))),
                safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance()),
                "testMKRWipe#4"
            );
        }
    }

    function testMKRHarvest() public {
        setStabilityFee(uint256(1000000115165872987700711356)); // 1 % day
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        warp(1 days);
        uint256 expectedDebt = 101 ether;
        assertEqTol(clerk.debt(), expectedDebt, "testMKRHarvest#1");

        warp(3 days);

        uint256 seniorPrice = mkrAssessor.calcSeniorTokenPrice();
        uint256 juniorPrice = mkrAssessor.calcJuniorTokenPrice();

        uint256 lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer
        uint256 profitDAI = safeSub(lockedCollateralDAI, clerk.calcOvercollAmount(clerk.debt()));
        uint256 preSeniorAsset = safeAdd(assessor.seniorDebt(), assessor.seniorBalance_());

        uint256 preJuniorStake = clerk.juniorStake();

        clerk.harvest();

        uint256 newJuniorPrice = mkrAssessor.calcJuniorTokenPrice();

        uint256 fixed27Tolerance = 100000000;
        assertEq(newJuniorPrice, juniorPrice, fixed27Tolerance);
        assertEqTol(preJuniorStake, safeAdd(clerk.juniorStake(), profitDAI), "testMKRHarvest#2");
        assertEqTol(
            safeSub(preSeniorAsset, profitDAI),
            safeAdd(assessor.seniorDebt(), assessor.seniorBalance_()),
            "testMKRHarvest#3"
        );
    }

    function testMKRHeal() public {
        // high stability fee: 10% a day
        clerk.file("tolerance", 0);
        uint256 fee = uint256(1000001103127689513476993126);
        setStabilityFee(fee);

        // sanity check
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        warp(1 days);
        uint256 expectedDebt = 110 ether;

        uint256 seniorPrice = mkrAssessor.calcSeniorTokenPrice();
        uint256 lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        assertEqTol(clerk.debt(), expectedDebt, "testMKRHeal#1");

        uint256 wantedLocked = clerk.calcOvercollAmount(clerk.debt());
        assertTrue(wantedLocked > lockedCollateralDAI);

        uint256 amountOfDROP = clerk.cdpink();

        clerk.heal();
        // heal should have minted additional DROP tokens
        lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        assertEqTol(lockedCollateralDAI, wantedLocked, "testMKRHeal#2");
        assertTrue(clerk.cdpink() > amountOfDROP);
    }

    function testFailMKRSinkTooHigh() public {
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        uint256 sinkAmount = 401 ether;
        clerk.sink(sinkAmount);
    }

    function testVaultLiquidation() public {
        _setUpOngoingMKR();
        uint256 juniorTokenPrice = mkrAssessor.calcJuniorTokenPrice();

        // liquidation
        makerEvent("live", false);

        assertTrue(mkrAssessor.calcJuniorTokenPrice() < juniorTokenPrice);
        // no currency in reserve
        assertEq(reserve.totalBalance(), 0);

        // repay loans and everybody redeems
        repayAllDebtDefaultLoan();
        assertEq(mkrAssessor.getNAV(), 0);
        // reserve should keep the currency no automatic clerk.wipe
        assertTrue(reserve.totalBalance() > 0);

        _mkrLiquidationPostAssertions();
    }

    function testVaultLiquidation2() public {
        _setUpOngoingMKR();
        makerEvent("glad", false);
        _mkrLiquidationPostAssertions();
    }

    function testVaultLiquidation3() public {
        _setUpOngoingMKR();
        makerEvent("safe", false);
        _mkrLiquidationPostAssertions();
    }

    function testFailLiqDraw() public {
        _setUpOngoingMKR();
        makerEvent("glad", false);
        clerk.draw(1);
    }

    function testFailLiqSink() public {
        _setUpOngoingMKR();
        makerEvent("glad", false);
        clerk.sink(1);
    }

    function testFailLiqWipe() public {
        _setUpOngoingMKR();
        makerEvent("glad", false);
        // repay loans and everybody redeems
        repayAllDebtDefaultLoan();
        assertTrue(reserve.totalBalance() > 0);
        clerk.wipe(1);
    }

    function testDrawWipeDrawAgain() public {
        uint256 fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 500 ether;
        uint256 borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        warp(1 days);
        uint256 expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testDrawWipeDrawAgain#1");

        // repay loan and entire maker debt
        uint256 repayAmount = expectedDebt;
        repayDefaultLoan(repayAmount);

        assertEqTol(clerk.debt(), 0, "testDrawWipeDrawAgain#2");
        assertEq(reserve.totalBalance(), 0, "testDrawWipeDrawAgain#3");

        // draw again
        borrowAmount = 50 ether;
        setupOngoingDefaultLoan(borrowAmount);
        assertEqTol(clerk.debt(), borrowAmount, "testDrawWipeDrawAgain#4");
    }

    function testDrawMax() public {
        uint256 fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 100 ether;
        uint256 borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        assertEq(clerk.remainingCredit(), 0);

        warp(1 days);
        uint256 expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testDrawMax#1");
        assertEq(clerk.remainingCredit(), 0);

        // repay loan and entire maker debt
        uint256 repayAmount = expectedDebt;
        repayDefaultLoan(repayAmount);
        assertEqTol(clerk.debt(), 0, "testDrawMax#4");
    }

    function testLoanRepayToMKRAndReserve() public {
        uint256 fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 100 ether;
        uint256 borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        assertEq(clerk.remainingCredit(), 0);

        assertEq(clerk.debt(), mkrAmount, "testLoanRepayToMKRAndReserve#1");

        warp(1 days);
        uint256 expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testLoanRepayToMKRAndReserve#2");
        assertEq(clerk.remainingCredit(), 0);

        // repay loan and entire maker debt
        uint256 loan = 1;
        uint256 repayAmount = pile.debt(loan);
        repayDefaultLoan(repayAmount);

        assertEqTol(clerk.debt(), 0, "testLoanRepayToMKRAndReserve#3");
        assertEq(reserve.totalBalance(), repayAmount - expectedDebt);
    }

    function testMKRDebtHigherThanCollateral() public {
        uint256 fee = uint256(1000001103127689513476993126); // 10% per day
        setStabilityFee(fee);
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 300 ether;
        uint256 borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        warp(4 days);

        assertTrue(clerk.debt() > clerk.cdpink());

        nftFeed.calcUpdateNAV();

        // repay entire debt
        // normally the maker liquidation would kick in that scenario
        uint256 loan = 1;
        uint256 repayAmount = pile.debt(loan);
        repayDefaultLoan(repayAmount);
        assertEqTol(clerk.debt(), 0, "testMKRDebtHigherThan#2");
    }

    function testJuniorLostAllRepayToMKR() public {
        uint256 fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint256 juniorAmount = 200 ether;
        uint256 mkrAmount = 300 ether;
        uint256 borrowAmount = 250 ether;

        uint256 firstLoan = 1;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        // second loan same ammount
        setupOngoingDefaultLoan(borrowAmount);
        warp(1 days);
        // repay small amount of loan debt
        uint256 repayAmount = 5 ether;
        repayDefaultLoan(repayAmount);

        warp(5 days);
        // write 50% of debt off / second loan 100% loss
        root.relyContract(address(pile), address(this));
        root.relyContract(address(nftFeed), address(this));
        nftFeed.overrideWriteOff(1, 1);
        nftFeed.overrideWriteOff(2, 3);

        nftFeed.calcUpdateNAV();
        assertTrue(mkrAssessor.calcSeniorTokenPrice() > 0);
        assertEq(mkrAssessor.calcJuniorTokenPrice(), 0);
        assertTrue(clerk.debt() > clerk.cdpink());

        uint256 preClerkDebt = clerk.debt();

        repayAmount = 50 ether;
        repayDefaultLoan(repayAmount);

        assertEqTol(clerk.debt(), preClerkDebt - repayAmount, "testJuniorLostAll#1");
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

    function testWipeAndDrawWithAutoHeal() public {
        _wipeAndDrawWithAutoHeal(1 days);
    }

    function testFailAutoHeal() public {
        clerk.file("autoHealMax", 0.1 * 1 ether);
        _wipeAndDrawWithAutoHeal(1 days);
    }

    function _wipeAndDrawWithAutoHeal(uint256 timeUntilExecute) public {
        root.relyContract(address(mkrAssessor), address(this));
        mkrAssessor.file("minSeniorRatio", 0);

        // initial junior & senior investments
        uint256 seniorSupplyAmount = 800 ether;
        uint256 juniorSupplyAmount = 400 ether;
        juniorSupply(juniorSupplyAmount);
        seniorSupply(seniorSupplyAmount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        seniorInvestor.disburse();
        juniorInvestor.disburse();
        assertTrue(coordinator.submissionPeriod() == false);

        //setup maker creditline
        uint256 mkrCreditline = 800 ether;
        root.relyContract(address(reserve), address(this));
        // activate clerk in reserve
        reserve.depend("lending", address(clerk));
        clerk.raise(mkrCreditline);
        assertEq(clerk.remainingCredit(), mkrCreditline);

        // borrow loan & draw from maker
        uint256 borrowAmount = 1600 ether;
        setupOngoingDefaultLoan(borrowAmount);
        uint256 debt = safeSub(borrowAmount, safeAdd(seniorSupplyAmount, juniorSupplyAmount));
        assertEq(clerk.debt(), debt);

        // submit new supply & redeem orders into the pool under following conditions
        // epoch close & epoch execution should not happen in same block, so that DROP price is different during closign & execution
        // senior supply should wipe maker debt
        // junior redeem should draw from maker

        // 1. close epoch --> juniorRedeem amount too high, epoch won't execute automatically
        hevm.warp(block.timestamp + 1 days);
        seniorSupply(200 ether);
        juniorInvestor.redeemOrder(400 ether);
        coordinator.closeEpoch();
        uint256 seniorTokenPriceClosing = mkrAssessor.calcSeniorTokenPrice();
        assertTrue(coordinator.submissionPeriod() == true);

        // 2. submit solution & execute epoch
        hevm.warp(block.timestamp + timeUntilExecute);
        // valid submission
        ModelInput memory submission = ModelInput({
            seniorSupply: 200 ether, // --> calls maker wipe
            juniorSupply: 0 ether,
            seniorRedeem: 0 ether,
            juniorRedeem: 1 ether // --> calls maker draw
        });
        int256 valid = submitSolution(address(coordinator), submission);
        assertEq(valid, coordinator.NEW_BEST());
        hevm.warp(block.timestamp + 2 hours);
        coordinator.executeEpoch();
        // check for DROP token price
        uint256 seniorTokenPriceExecution = mkrAssessor.calcSeniorTokenPrice();
        // drop price during epoch execution higher then during epoch closing -> requires healing
        assertTrue(seniorTokenPriceClosing < seniorTokenPriceExecution);
        assertTrue(coordinator.submissionPeriod() == false);
    }

    function testWipeAndDrawWithAutoHealSameBlock() public {
        root.relyContract(address(mkrAssessor), address(this));
        mkrAssessor.file("minSeniorRatio", 0);

        // initial junior & senior investments
        uint256 seniorSupplyAmount = 800 ether;
        uint256 juniorSupplyAmount = 400 ether;
        juniorSupply(juniorSupplyAmount);
        seniorSupply(seniorSupplyAmount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        seniorInvestor.disburse();
        juniorInvestor.disburse();
        assertTrue(coordinator.submissionPeriod() == false);

        //setup maker creditline
        uint256 mkrCreditline = 800 ether;
        root.relyContract(address(reserve), address(this));
        // activate clerk in reserve
        reserve.depend("lending", address(clerk));
        clerk.raise(mkrCreditline);
        assertEq(clerk.remainingCredit(), mkrCreditline);

        // borrow loan & draw from maker
        uint256 borrowAmount = 1600 ether;
        setupOngoingDefaultLoan(borrowAmount);
        uint256 debt = safeSub(borrowAmount, safeAdd(seniorSupplyAmount, juniorSupplyAmount));
        assertEq(clerk.debt(), debt);

        // submit new supply & redeem orders into the pool under following conditions
        // epoch close & epoch execution should happen in same block, so that no healing is required

        // 1. close epoch --> juniorRedeem amount too high, epoch won't execute automatically
        hevm.warp(block.timestamp + 1 days);
        seniorSupply(200 ether);
        juniorInvestor.redeemOrder(1 ether);
        coordinator.closeEpoch(); // auto execute epoch in teh same block
        assertTrue(coordinator.submissionPeriod() == false);
    }
}
