// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "./base_system.sol";

contract TestSuite is BaseSystemTest {

    uint constant DEFAULT_LOAN_ID = 1;
    uint constant DEFAULT_MATURITY_DATE = 5 days;

    function seniorSupply(uint currencyAmount) public {
        seniorSupply(currencyAmount, seniorInvestor);
    }

    function seniorSupply(uint currencyAmount, Investor investor) public {
        admin.makeSeniorTokenMember(address(investor), safeAdd(block.timestamp, 8 days));
        currency.mint(address(investor), currencyAmount);
        investor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = seniorTranche.users(address(investor));
        assertEq(supplyAmount, currencyAmount);
    }

    function juniorSupply(uint currencyAmount) public {
        currency.mint(address(juniorInvestor), currencyAmount);
        admin.makeJuniorTokenMember(juniorInvestor_, safeAdd(block.timestamp, 8 days));
        juniorInvestor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = juniorTranche.users(juniorInvestor_);
        assertEq(supplyAmount, currencyAmount);
    }

    function closeEpoch(bool closeWithExecute) public {
        uint currentEpoch = coordinator.currentEpoch();
        uint lastEpochExecuted = coordinator.lastEpochExecuted();

        coordinator.closeEpoch();
        assertEq(coordinator.currentEpoch(), currentEpoch+1);
        if(closeWithExecute == true) {
            lastEpochExecuted++;
        }
        assertEq(coordinator.lastEpochExecuted(), lastEpochExecuted);
    }

    function setupOngoingDefaultLoan(uint borrowAmount) public returns(uint) {
        // borrow loans with default maturity date 5 days from now
        uint maturityDate = DEFAULT_MATURITY_DATE;
        uint nftPrice = borrowAmount*3;
        (uint loan, ) = setupOngoingLoan(nftPrice, borrowAmount, nftFeed.uniqueDayTimestamp(block.timestamp) + maturityDate);
        return loan;

    }

    function repayDefaultLoan(uint currencyAmount) public {
        address usr = address(borrower);
        repayLoan(usr, DEFAULT_LOAN_ID, currencyAmount);
    }

    function repayAllDebtDefaultLoan() public {
        uint debt = pile.debt(DEFAULT_LOAN_ID);
        repayDefaultLoan(debt);
    }

    function supplyAndBorrowFirstLoan(uint seniorSupplyAmount, uint juniorSupplyAmount,
        uint nftPrice, uint borrowAmount, uint maturityDate, ModelInput memory submission) public returns (uint loan, uint tokenId) {
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(block.timestamp + 1 days);

        closeEpoch(false);
        assertTrue(coordinator.submissionPeriod() == true);

        int valid = submitSolution(address(coordinator), submission);
        assertEq(valid, coordinator.NEW_BEST());

        hevm.warp(block.timestamp + 2 hours);

        coordinator.executeEpoch();
        assertEqTol(reserve.totalBalance(), submission.seniorSupply + submission.juniorSupply, " firstLoan#1");

        // senior
        (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) = seniorInvestor.disburse();
        // equal because of token price 1
        assertEqTol(payoutTokenAmount, submission.seniorSupply, " firstLoan#2");
        assertEqTol(remainingSupplyCurrency, seniorSupplyAmount- submission.seniorSupply, " firstLoan#3");

        // junior
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) = juniorInvestor.disburse();
        assertEqTol(payoutTokenAmount, submission.juniorSupply," firstLoan#4");
        assertEqTol(remainingSupplyCurrency, juniorSupplyAmount- submission.juniorSupply, " firstLoan#5");

        assertEqTol(seniorToken.balanceOf(seniorInvestor_), submission.seniorSupply, " firstLoan#6");
        assertEqTol(juniorToken.balanceOf(juniorInvestor_), submission.juniorSupply, " firstLoan#7");


        // borrow loans maturity date 5 days from now
        (loan, tokenId) = setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(block.timestamp) +maturityDate);

        assertEqTol(currency.balanceOf(address(borrower)), borrowAmount, " firstLoan#8");
        uint nav = nftFeed.calcUpdateNAV();

        // seniorDebt is equal to the nav multiplied with the seniorRatio for the first loan
        assertEqTol(assessor.seniorDebt(), rmul(nav, assessor.seniorRatio()), " firstLoan#9");

        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve.totalBalance());
        assertEqTol(seniorTokenPrice, rdiv(safeAdd(assessor.seniorDebt(), assessor.seniorBalance_()),  seniorToken.totalSupply()), " firstLoan#10");

        return (loan, tokenId);
    }
}
