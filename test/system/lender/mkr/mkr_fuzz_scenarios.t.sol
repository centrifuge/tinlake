// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../../test_suite.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "test/lender/coordinator-base.t.sol";
import {MKRTestBasis} from "./mkr_basic.t.sol";

interface MockLike {
    function setReturn(bytes32 name, uint returnValue) external;
}

contract MKRLoanFuzzTest is MKRTestBasis {
    uint MAX_CURRENCY_NUMBER = 10 ** 30;
    function dripMakerDebt() public {}

    function setStabilityFee(uint fee) public {
        mkr.file("stabilityFee", fee);
    }

    function warp(uint plusTime) public {
        hevm.warp(block.timestamp + plusTime);
    }

    function checkRange(uint val, uint min, uint max) public returns (bool) {
        if (val >= min && val <= max) {
            return true;
        }
        return false;
    }

    function invest(uint juniorAmount, uint seniorAmount, uint mkrAmount) public {
        root.relyContract(address(reserve), address(this));

        root.relyContract(address(mkrAssessor), address(this));
        mkrAssessor.file("minSeniorRatio", 0);

        // activate clerk in reserve
        reserve.depend("lending", address(clerk));

        juniorSupply(juniorAmount);
        seniorSupply(seniorAmount);

        hevm.warp(block.timestamp + 1 days);

        bool closeWithExecute = true;
        closeEpoch(closeWithExecute);
        assertTrue(coordinator.submissionPeriod() == false);

        clerk.raise(mkrAmount);
        assertEq(clerk.remainingCredit(), mkrAmount);
    }

    function borrow(uint borrowAmount) public {
        setupOngoingDefaultLoan(borrowAmount);
        assertEq(currency.balanceOf(address(borrower)), borrowAmount, " borrow#1");

        emit log_named_uint("seniorRatio", assessor.seniorRatio());
        // seniorDebt should equal to seniorRatio from the current NAV
        // todo figure out why rounding differences
       // assertEq(assessor.seniorDebt(), rmul(nftFeed.currentNAV(), assessor.seniorRatio()), "seniorDebtCheck");
        // check if seniorRatio is correct
        assertEq(assessor.seniorRatio(), rdiv(safeAdd(assessor.seniorDebt(), assessor.effectiveSeniorBalance()),
            safeAdd(nftFeed.currentNAV(), reserve.totalBalance())));

    }

    // fuzz testing borrow and repay loan
    // additional liquidity might come from Maker on some cases
    function testBorrowRepayFuzz(uint totalAvailable, uint borrowAmount) public {
        if (borrowAmount > totalAvailable) {
            return;
        }

        if(!checkRange(borrowAmount, 1 ether, MAX_CURRENCY_NUMBER) || !checkRange(totalAvailable, 1 ether, MAX_CURRENCY_NUMBER)) {
            return;
        }

        uint fee = uint(1000000229200000000000000000); // 2% per day
        setStabilityFee(fee);
        uint juniorAmount = rmul(totalAvailable, 0.3 * 10**27);
        uint totalSenior = rmul(totalAvailable, 0.7 * 10**27);

        // DROP split randomly between senior investors and MKR
        uint split = totalSenior % 100;
        uint seniorAmount = rmul(totalSenior, split * 10**25);
        uint makerAmount = totalSenior-seniorAmount;

        emit log_named_uint("juniorAmount", juniorAmount / 1 ether);
        emit log_named_uint("makerCreditLine", makerAmount / 1 ether);
        emit log_named_uint("seniorAmount", seniorAmount / 1 ether);
        emit log_named_uint("borrowAmount", borrowAmount / 1 ether);
        emit log_named_uint("seniorAmount percentage", split);

        invest(juniorAmount, seniorAmount, makerAmount);
        borrow(borrowAmount);

        uint drawTimestamp = block.timestamp;

        // different repayment time
        uint passTime = totalAvailable % DEFAULT_MATURITY_DATE;
        emit log_named_uint("pass in seconds", passTime);
        warp(passTime);

        uint expectedDebt = chargeInterest(borrowAmount, fee, drawTimestamp);

        // repay loan and entire maker debt
        uint repayAmount = expectedDebt;

        uint preMakerDebt = clerk.debt();
        uint preReserve = reserve.totalBalance();
        // check prices
        emit log_named_uint("makerDebt", preMakerDebt);

        repayDefaultLoan(repayAmount);

        // check post state
        if(repayAmount > preMakerDebt) {
            assertEqTol(clerk.debt(), 0, "testDrawWipeDrawAgain#2");
            assertEq(reserve.totalBalance(), preReserve+repayAmount-preMakerDebt, "testDrawWipeDrawAgain#3");
        } else {
            assertEq(clerk.debt(), preReserve+preMakerDebt-repayAmount,"testDrawWipeDrawAgain#3");
        }

        // check prices
        emit log_named_uint("juniorTokenPrice", assessor.calcJuniorTokenPrice());
        emit log_named_uint("seniorTokenPrice", assessor.calcSeniorTokenPrice());

        assertTrue(assessor.calcJuniorTokenPrice() > ONE);
        assertTrue(assessor.calcSeniorTokenPrice() >= ONE);
//        assertTrue(assessor.calcJuniorTokenPrice() > assessor.calcSeniorTokenPrice());
    }

    function testBorrowRepayFuzzWithoutOvercollateralization(uint totalAvailable, uint borrowAmount) public {
        if (borrowAmount > totalAvailable) {
            return;
        }

        if(!checkRange(borrowAmount, 1 ether, MAX_CURRENCY_NUMBER) || !checkRange(totalAvailable, 1 ether, MAX_CURRENCY_NUMBER)) {
            return;
        }

        MockLike(address(clerk.spotter())).setReturn("mat", 10**27);
        clerk.file("buffer", 0);

        uint fee = uint(1000000229200000000000000000); // 2% per day
        setStabilityFee(fee);
        uint juniorAmount = rmul(totalAvailable, 0.3 * 10**27);
        uint totalSenior = rmul(totalAvailable, 0.7 * 10**27);

        // DROP split randomly between senior investors and MKR
        uint split = totalSenior % 100;
        uint seniorAmount = rmul(totalSenior, split * 10**25);
        uint makerAmount = totalSenior-seniorAmount;

        emit log_named_uint("juniorAmount", juniorAmount / 1 ether);
        emit log_named_uint("makerCreditLine", makerAmount / 1 ether);
        emit log_named_uint("seniorAmount", seniorAmount / 1 ether);
        emit log_named_uint("borrowAmount", borrowAmount / 1 ether);
        emit log_named_uint("seniorAmount percentage", split);

        invest(juniorAmount, seniorAmount, makerAmount);
        borrow(borrowAmount);

        uint drawTimestamp = block.timestamp;

        // different repayment time
        uint passTime = totalAvailable % DEFAULT_MATURITY_DATE;
        emit log_named_uint("pass in seconds", passTime);
        warp(passTime);

        uint expectedDebt = chargeInterest(borrowAmount, fee, drawTimestamp);

        // repay loan and entire maker debt
        uint repayAmount = expectedDebt;

        uint preMakerDebt = clerk.debt();
        uint preReserve = reserve.totalBalance();
        // check prices
        emit log_named_uint("makerDebt", preMakerDebt);

        repayDefaultLoan(repayAmount);

        // check post state
        if(repayAmount > preMakerDebt) {
            assertEqTol(clerk.debt(), 0, "testDrawWipeDrawAgain#2");
            assertEq(reserve.totalBalance(), preReserve+repayAmount-preMakerDebt, "testDrawWipeDrawAgain#3");
        } else {
            assertEq(clerk.debt(), preReserve+preMakerDebt-repayAmount,"testDrawWipeDrawAgain#3");
        }

        // check prices
        emit log_named_uint("juniorTokenPrice", assessor.calcJuniorTokenPrice());
        emit log_named_uint("seniorTokenPrice", assessor.calcSeniorTokenPrice());

        assertTrue(assessor.calcJuniorTokenPrice() > ONE);
        assertTrue(assessor.calcSeniorTokenPrice() >= ONE);
//        assertTrue(assessor.calcJuniorTokenPrice() > assessor.calcSeniorTokenPrice());
    }
}
