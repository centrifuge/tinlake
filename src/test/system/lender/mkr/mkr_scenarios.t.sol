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
    function testOnDemandDrawWithStabilityFee() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(now + 1 days);
        assertEq(clerk.debt(), 105 ether, "testStabilityFee#2");
    }

    function testLoanRepayWipe() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;

        emit log_named_uint("stability fee", clerk.stabilityFee());
        emit log_named_uint("debt", clerk.debt());
        emit log_named_uint("remaining", clerk.remainingCredit());
        emit log_named_uint("senior", assessor.seniorBalance());
        emit log_named_uint("senior", assessor.seniorDebt());
        emit log_named_uint("assess.or", mkrAssessor.remainingCredit());

        emit log_named_uint("sdf", 1);
        emit log_named_uint("cdptab", clerk.cdptab());

        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        emit log_named_uint("done draw", clerk.cdptab());

        hevm.warp(now + 1 days);
        uint expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testLoanRepayWipe#1");

        uint repayAmount = 50 ether;
        repayDefaultLoan(repayAmount);

        // reduces clerk debt
        assertEqTol(clerk.debt(), safeSub(expectedDebt, repayAmount), "testLoanRepayWipe#2");
        assertEq(reserve.totalBalance(), 0, "testLoanRepayWipe#3");
    }

    function testMKRHarvest() public {
        uint fee = uint(1000000115165872987700711356);    // 1 % day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(now + 1 days);
        uint expectedDebt = 101 ether;
        assertEqTol(clerk.debt(), expectedDebt, "testMKRHarvest#1");

        hevm.warp(now + 3 days);

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
        mkr.file("stabilityFee", fee);

        // sanity check
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        hevm.warp(now + 1 days);
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
        mkr.file("live", false);

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
        mkr.file("glad", false);
        _mkrLiquidationPostAssertions();
    }

    function testVaultLiquidation3() public {
        _setUpOngoingMKR();
        mkr.file("safe", false);
        _mkrLiquidationPostAssertions();
    }

    function testFailLiqDraw() public {
        _setUpOngoingMKR();
        mkr.file("glad", false);
        clerk.draw(1);
    }

    function testFailLiqSink() public {
        _setUpOngoingMKR();
        mkr.file("glad", false);
        clerk.sink(1);
    }

    function testFailLiqWipe() public {
        _setUpOngoingMKR();
        mkr.file("glad", false);
        // repay loans and everybody redeems
        repayAllDebtDefaultLoan();
        assertTrue(reserve.totalBalance() > 0);
        clerk.wipe(1);
    }
}
