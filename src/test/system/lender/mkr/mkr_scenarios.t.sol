// Copyright (C) 2020 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "../../test_suite.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "../../../../lender/test/coordinator-base.t.sol";
import {MKRTestBasis} from "./mkr_basic.t.sol";

contract MKRLenderSystemTest is MKRTestBasis {
    function dripMakerDebt() public {}

    function setStabilityFee(uint fee) public {
        mkr.file("stabilityFee", fee);
    }

    function makerEvent(bytes32 name, bool flag) public {
        mkr.file(name, flag);
    }

    function warp(uint plusTime) public {
        hevm.warp(now + plusTime);
    }

    function testOnDemandDrawWithStabilityFee() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        warp(1 days);
        assertEq(clerk.debt(), 105 ether, "testStabilityFee#2");
    }


    function testMKRWipe() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 500 ether;
        uint repayAmount = 100 ether;
        mkrWipe(juniorAmount, mkrAmount, borrowAmount, repayAmount, false);
    }

    function testMKRWipeRepayHigherThanJunior() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 500 ether;
        uint repayAmount = 300 ether;
        mkrWipe(juniorAmount, mkrAmount, borrowAmount, repayAmount, true);
    }

    function mkrWipe(uint juniorAmount, uint mkrAmount, uint borrowAmount, uint repayAmount, bool doPreHarvest) public {
        setStabilityFee(uint(1000000115165872987700711356));   // 1 % day
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        warp(1 days);

        uint expectedDebt = 303 ether;
        assertEqTol(clerk.debt(), expectedDebt, "testMKRWipe#1");
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer

        uint preLockedDAIHarvest = rmul(clerk.cdpink(), mkrAssessor.calcSeniorTokenPrice());
        uint preSeniorAssetHarvest = safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance());

        // harvest before wipe call
        if (doPreHarvest) {
            clerk.harvest();
        }
        uint preRequiredLocked = clerk.calcOvercollAmount(clerk.debt());
        uint preSeniorAsset = safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance());

        // wipe is triggered by repay
        repayDefaultLoan(repayAmount);

        // reduces clerk debt
        assertEqTol(clerk.debt(), safeSub(expectedDebt, repayAmount), "testMKRWipe#2");
        assertEq(reserve.totalBalance(), 0, "testMKRWipe#3");

        uint decreaseSeniorAsset = safeSub(preLockedDAIHarvest, rmul(clerk.cdpink(), mkrAssessor.calcSeniorTokenPrice()));
        assertEqTol(safeSub(preSeniorAssetHarvest, decreaseSeniorAsset),  safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance()),"testMKRWipe#4");
        if (doPreHarvest) {
            assertEqTol(safeSub(preSeniorAsset, safeSub(preRequiredLocked,clerk.calcOvercollAmount(clerk.debt()))),
                safeAdd(mkrAssessor.seniorDebt(), mkrAssessor.effectiveSeniorBalance()),"testMKRWipe#4");
        }
    }

    function testMKRHarvest() public {
        setStabilityFee(uint(1000000115165872987700711356));   // 1 % day
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        warp(1 days);
        uint expectedDebt = 101 ether;
        assertEqTol(clerk.debt(), expectedDebt, "testMKRHarvest#1");

        warp(3 days);

        uint seniorPrice = mkrAssessor.calcSeniorTokenPrice();
        uint juniorPrice = mkrAssessor.calcJuniorTokenPrice();

        uint lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer
        uint profitDAI = safeSub(lockedCollateralDAI, clerk.calcOvercollAmount(clerk.debt()));
        uint preSeniorAsset = safeAdd(assessor.seniorDebt(), assessor.seniorBalance_());

        uint preJuniorStake = clerk.juniorStake();

        clerk.harvest();

        uint newJuniorPrice = mkrAssessor.calcJuniorTokenPrice();
        uint newSeniorPrice =  mkrAssessor.calcSeniorTokenPrice();

        uint fixed27Tolerance = 100000000;
        assertEq(newJuniorPrice, juniorPrice, fixed27Tolerance);
        assertEqTol(preJuniorStake, safeAdd(clerk.juniorStake(), profitDAI), "testMKRHarvest#2");
        assertEqTol(safeSub(preSeniorAsset,profitDAI), safeAdd(assessor.seniorDebt(), assessor.seniorBalance_()), "testMKRHarvest#3");
    }

    function testMKRHeal() public {
        // high stability fee: 10% a day
        clerk.file("tolerance", 0);
        uint fee = uint(1000001103127689513476993126);
        setStabilityFee(fee);

        // sanity check
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        warp(1 days);
        uint expectedDebt = 110 ether;

        uint seniorPrice = mkrAssessor.calcSeniorTokenPrice();
        uint lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        assertEqTol(clerk.debt(), expectedDebt, "testMKRHeal#1");

        uint wantedLocked = clerk.calcOvercollAmount(clerk.debt());
        assertTrue(wantedLocked > lockedCollateralDAI);

        uint amountOfDROP = clerk.cdpink();

        clerk.heal();
        // heal should have minted additional DROP tokens
        lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        assertEqTol(lockedCollateralDAI, wantedLocked, "testMKRHeal#2");
        assertTrue(clerk.cdpink() > amountOfDROP);
    }

    function testFailMKRSinkTooHigh() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        uint sinkAmount = 401 ether;
        clerk.sink(sinkAmount);
    }

    function testVaultLiquidation() public {
        _setUpOngoingMKR();
        uint juniorTokenPrice = mkrAssessor.calcJuniorTokenPrice();

        // liquidation
        makerEvent("live", false);

        assertTrue(mkrAssessor.calcJuniorTokenPrice() <  juniorTokenPrice);
        // no currency in reserve
        assertEq(reserve.totalBalance(),  0);

        // repay loans and everybody redeems
        repayAllDebtDefaultLoan();
        assertEq(mkrAssessor.currentNAV(), 0);
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
        uint fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        warp(1 days);
        uint expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testDrawWipeDrawAgain#1");

        // repay loan and entire maker debt
        uint repayAmount = expectedDebt;
        repayDefaultLoan(repayAmount);

        assertEqTol(clerk.debt(), 0, "testDrawWipeDrawAgain#2");
        assertEq(reserve.totalBalance(), 0, "testDrawWipeDrawAgain#3");

        // draw again
        borrowAmount = 50 ether;
        setupOngoingDefaultLoan(borrowAmount);
        assertEqTol(clerk.debt(), borrowAmount, "testDrawWipeDrawAgain#4");
    }

    function testDrawMax() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 100 ether;
        uint borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        assertEq(clerk.remainingCredit(), 0);

        warp(1 days);
        uint expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testDrawMax#1");
        assertEq(clerk.remainingCredit(), 0);

        // repay loan and entire maker debt
        uint repayAmount = expectedDebt;
        repayDefaultLoan(repayAmount);
        assertEqTol(clerk.debt(), 0, "testDrawMax#4");
    }

    function testLoanRepayToMKRAndReserve() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 100 ether;
        uint borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        assertEq(clerk.remainingCredit(), 0);

        warp(1 days);
        uint expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testLoanRepayToMKRAndReserve#1");
        assertEq(clerk.remainingCredit(), 0);

        // repay loan and entire maker debt
        uint loan = 1;
        uint repayAmount = pile.debt(loan);
        repayDefaultLoan(repayAmount);

        assertEqTol(clerk.debt(), 0, "testLoanRepayToMKRAndReserve#2");
        assertEq(reserve.totalBalance(), repayAmount-expectedDebt);
    }

    function testMKRDebtHigherThanCollateral() public {
        uint fee = uint(1000001103127689513476993126); // 10% per day
        setStabilityFee(fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 300 ether;
        uint borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        warp(4 days);

        assertTrue(clerk.debt() > clerk.cdpink());

        nftFeed.calcUpdateNAV();

        // repay entire debt
        // normally the maker liquidation would kick in that scenario
        uint loan = 1;
        uint repayAmount = pile.debt(loan);
        repayDefaultLoan(repayAmount);
        assertEqTol(clerk.debt(), 0, "testMKRDebtHigherThan#2");
    }

    function testJuniorLostAllRepayToMKR() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 300 ether;
        uint borrowAmount = 250 ether;

        uint firstLoan = 1;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        // second loan same ammount
        uint secondLoan = setupOngoingDefaultLoan(borrowAmount);
        warp(1 days);
        // repay small amount of loan debt
        uint repayAmount = 5 ether;
        repayDefaultLoan(repayAmount);

        // nav will be zero because loan is overdue
        warp(5 days);
        // write 40% of debt off / second loan 100% loss
        root.relyContract(address(pile), address(this));
        pile.changeRate(firstLoan, nftFeed.WRITE_OFF_PHASE_A());

        assertTrue(mkrAssessor.calcSeniorTokenPrice() > 0);
        assertEq(mkrAssessor.calcJuniorTokenPrice(), 0);
        assertTrue(clerk.debt() > clerk.cdpink());

        uint preClerkDebt = clerk.debt();

        repayAmount = 50 ether;
        repayDefaultLoan(repayAmount);

        assertEqTol(clerk.debt(), preClerkDebt-repayAmount, "testJuniorLostAll#1");

    }

    function testRedeemCurrencyFromMKR() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        (,uint payoutTokenAmount,,) = juniorInvestor.disburse();

        uint redeemTokenAmount = 20 ether;
        juniorInvestor.redeemOrder(redeemTokenAmount);
        hevm.warp(now + 1 days);
        // currency should come from MKR
        assertEq(reserve.totalBalance(), 0);
        coordinator.closeEpoch();
        (uint payoutCurrency,,,uint remainingRedeemToken) = juniorInvestor.disburse();
        // juniorTokenPrice should be still ONE
        assertEq(currency.balanceOf(address(juniorInvestor)), payoutCurrency);
    }
}
