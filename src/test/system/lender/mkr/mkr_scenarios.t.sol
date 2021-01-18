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

pragma solidity >=0.5.15 <0.6.0;
pragma experimental ABIEncoderV2;

import "../../test_suite.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "../../../../lender/test/coordinator-base.t.sol";
import { MKRAssessor }from "../../../../lender/adapters/mkr/assessor.sol";
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

    function testLoanRepayWipe() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        setStabilityFee(fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        warp(1 days);
        uint expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testLoanRepayWipe#1");

        uint repayAmount = 50 ether;
        repayDefaultLoan(repayAmount);

        // reduces clerk debt
        assertEqTol(clerk.debt(), safeSub(expectedDebt, repayAmount), "testLoanRepayWipe#2");
        assertEq(reserve.totalBalance(), 0, "testLoanRepayWipe#3");
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

        assertEq(newJuniorPrice, juniorPrice);
        assertEq(preJuniorStake, safeAdd(clerk.juniorStake(), profitDAI));
        assertEq(safeSub(preSeniorAsset,profitDAI), safeAdd(assessor.seniorDebt(), assessor.seniorBalance_()));
    }

    function testMKRHeal() public {
        // high stability fee: 10% a day
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
        assertEq(clerk.debt(), expectedDebt, "testLoanRepayWipe#1");

        // repay loan and entire maker debt
        uint repayAmount = expectedDebt;
        repayDefaultLoan(repayAmount);

        assertEqTol(clerk.debt(), 0, "testLoanRepayWipe#2");
        assertEq(reserve.totalBalance(), 0, "testLoanRepayWipe#3");

        // draw again
        borrowAmount = 50 ether;
        setupOngoingDefaultLoan(borrowAmount);
        assertEqTol(clerk.debt(), borrowAmount, "testLoanRepayWipe#4");
    }
}
