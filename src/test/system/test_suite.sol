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

import "ds-test/test.sol";
import "./base_system.sol";

contract TestSuite is BaseSystemTest {
    Hevm public hevm;

    uint defaultLoanId = 1;

    function seniorSupply(uint currencyAmount) public {
        seniorSupply(currencyAmount, seniorInvestor);
    }

    function seniorSupply(uint currencyAmount, Investor investor) public {
        admin.makeSeniorTokenMember(address(investor), safeAdd(now, 8 days));
        currency.mint(address(investor), currencyAmount);
        investor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = seniorTranche.users(address(investor));
        assertEq(supplyAmount, currencyAmount);
    }

    function juniorSupply(uint currencyAmount) public {
        currency.mint(address(juniorInvestor), currencyAmount);
        admin.makeJuniorTokenMember(juniorInvestor_, safeAdd(now, 8 days));
        juniorInvestor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = juniorTranche.users(juniorInvestor_);
        assertEq(supplyAmount, currencyAmount);
    }

    function closeEpoch(bool closeWithExecute) public {
        uint currentEpoch = coordinator.currentEpoch();
        uint lastEpochExecuted = coordinator.lastEpochExecuted();

        coordinator.closeEpoch();
        emit log_named_uint("fuchs", 1);
        assertEq(coordinator.currentEpoch(), currentEpoch+1);
        if(closeWithExecute == true) {
            lastEpochExecuted++;
        }
        assertEq(coordinator.lastEpochExecuted(), lastEpochExecuted);
    }

    function setupOngoingDefaultLoan(uint borrowAmount) public {
        // borrow loans maturity date 5 days from now
        uint maturityDate = 5 days;
        setupOngoingLoan(borrowAmount*3, borrowAmount, false, nftFeed.uniqueDayTimestamp(now) +maturityDate);
    }

    function repayDefaultLoan(uint currencyAmount) public {
        address usr = address(borrower);
        repayLoan(usr, defaultLoanId, currencyAmount);
    }

    function repayAllDebtDefaultLoan() public {
        uint debt = pile.debt(defaultLoanId);
        repayDefaultLoan(debt);
    }

    function supplyAndBorrowFirstLoan(uint seniorSupplyAmount, uint juniorSupplyAmount,
        uint nftPrice, uint borrowAmount, uint maturityDate, ModelInput memory submission) public returns (uint loan, uint tokenId) {
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(now + 1 days);

        closeEpoch(false);
        assertTrue(coordinator.submissionPeriod() == true);

        int valid = submitSolution(address(coordinator), submission);
        assertEq(valid, coordinator.NEW_BEST());

        hevm.warp(now + 2 hours);

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
        (loan, tokenId) = setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(now) +maturityDate);

        assertEqTol(currency.balanceOf(address(borrower)), borrowAmount, " firstLoan#8");
        uint nav = nftFeed.calcUpdateNAV();

        // seniorDebt doesn't reflect the NAV increase from the first loan
        assertEqTol(assessor.seniorDebt(), rmul(borrowAmount, assessor.seniorRatio()), " firstLoan#9");

        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve.totalBalance());
        assertEqTol(seniorTokenPrice, rdiv(safeAdd(assessor.seniorDebt(), assessor.seniorBalance_()),  seniorToken.totalSupply()), " firstLoan#10");

        return (loan, tokenId);
    }
}
