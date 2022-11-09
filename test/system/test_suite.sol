// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "./base_system.sol";

contract TestSuite is BaseSystemTest {
    uint256 constant DEFAULT_LOAN_ID = 1;
    uint256 constant DEFAULT_MATURITY_DATE = 5 days;

    function seniorSupply(uint256 currencyAmount) public {
        seniorSupply(currencyAmount, seniorInvestor);
    }

    function seniorSupply(uint256 currencyAmount, Investor investor) public {
        admin.makeSeniorTokenMember(address(investor), type(uint256).max);
        currency.mint(address(investor), currencyAmount);
        investor.supplyOrder(currencyAmount);
        (, uint256 supplyAmount,) = seniorTranche.users(address(investor));
        assertEq(supplyAmount, currencyAmount);
    }

    function juniorSupply(uint256 currencyAmount) public {
        currency.mint(address(juniorInvestor), currencyAmount);
        admin.makeJuniorTokenMember(juniorInvestor_, type(uint256).max);
        juniorInvestor.supplyOrder(currencyAmount);
        (, uint256 supplyAmount,) = juniorTranche.users(juniorInvestor_);
        assertEq(supplyAmount, currencyAmount);
    }

    function closeEpoch(bool closeWithExecute) public {
        uint256 currentEpoch = coordinator.currentEpoch();
        uint256 lastEpochExecuted = coordinator.lastEpochExecuted();

        coordinator.closeEpoch();
        assertEq(coordinator.currentEpoch(), currentEpoch + 1);
        if (closeWithExecute == true) {
            lastEpochExecuted++;
        }
        assertEq(coordinator.lastEpochExecuted(), lastEpochExecuted);
    }

    function setupOngoingDefaultLoan(uint256 borrowAmount) public returns (uint256) {
        // borrow loans with default maturity date 5 days from now
        uint256 maturityFromNow = DEFAULT_MATURITY_DATE;
        uint256 nftPrice = borrowAmount * 3;
        (uint256 loan,) =
            setupOngoingLoan(nftPrice, borrowAmount, nftFeed.uniqueDayTimestamp(block.timestamp) + maturityFromNow);
        return loan;
    }

    function repayDefaultLoan(uint256 currencyAmount) public {
        address usr = address(borrower);
        repayLoan(usr, DEFAULT_LOAN_ID, currencyAmount);
    }

    function repayAllDebtDefaultLoan() public {
        uint256 debt = pile.debt(DEFAULT_LOAN_ID);
        repayDefaultLoan(debt);
    }

    function supplyAndBorrowFirstLoan(
        uint256 seniorSupplyAmount,
        uint256 juniorSupplyAmount,
        uint256 nftPrice,
        uint256 borrowAmount,
        uint256 maturityDate,
        ModelInput memory submission
    ) public returns (uint256 loan, uint256 tokenId) {
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(block.timestamp + 1 days);

        closeEpoch(false);
        assertTrue(coordinator.submissionPeriod() == true);

        int256 valid = submitSolution(address(coordinator), submission);
        assertEq(valid, coordinator.NEW_BEST());

        hevm.warp(block.timestamp + 2 hours);

        coordinator.executeEpoch();
        assertEqTol(reserve.totalBalance(), submission.seniorSupply + submission.juniorSupply, " firstLoan#1");

        // senior
        (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        ) = seniorInvestor.disburse();
        // equal because of token price 1
        assertEqTol(payoutTokenAmount, submission.seniorSupply, " firstLoan#2");
        assertEqTol(remainingSupplyCurrency, seniorSupplyAmount - submission.seniorSupply, " firstLoan#3");

        // junior
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            juniorInvestor.disburse();
        assertEqTol(payoutTokenAmount, submission.juniorSupply, " firstLoan#4");
        assertEqTol(remainingSupplyCurrency, juniorSupplyAmount - submission.juniorSupply, " firstLoan#5");

        assertEqTol(seniorToken.balanceOf(seniorInvestor_), submission.seniorSupply, " firstLoan#6");
        assertEqTol(juniorToken.balanceOf(juniorInvestor_), submission.juniorSupply, " firstLoan#7");

        // borrow loans maturity date 5 days from now
        (loan, tokenId) =
            setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(block.timestamp) + maturityDate);

        assertEqTol(currency.balanceOf(address(borrower)), borrowAmount, " firstLoan#8");
        uint256 nav = nftFeed.calcUpdateNAV();

        // seniorDebt is equal to the nav multiplied with the seniorRatio for the first loan
        assertEqTol(assessor.seniorDebt(), rmul(nav, assessor.seniorRatio()), " firstLoan#9");

        uint256 seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve.totalBalance());
        assertEqTol(
            seniorTokenPrice,
            rdiv(safeAdd(assessor.seniorDebt(), assessor.seniorBalance_()), seniorToken.totalSupply()),
            " firstLoan#10"
        );

        return (loan, tokenId);
    }
}
