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
        assertEq(coordinator.currentEpoch(), currentEpoch+1);
        if(closeWithExecute == true) {
            lastEpochExecuted++;
        }
        assertEq(coordinator.lastEpochExecuted(), lastEpochExecuted);
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
        assertEq(reserve.totalBalance(), submission.seniorSupply + submission.juniorSupply);

        // senior
        (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) = seniorInvestor.disburse();
        // equal because of token price 1
        assertEq(payoutTokenAmount, submission.seniorSupply);
        assertEq(remainingSupplyCurrency, seniorSupplyAmount- submission.seniorSupply);

        // junior
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) = juniorInvestor.disburse();
        assertEq(payoutTokenAmount, submission.juniorSupply);
        assertEq(remainingSupplyCurrency, juniorSupplyAmount- submission.juniorSupply);

        assertEq(seniorToken.balanceOf(seniorInvestor_), submission.seniorSupply);
        assertEq(juniorToken.balanceOf(juniorInvestor_), submission.juniorSupply);

        // borrow loans maturity date 5 days from now
        (loan, tokenId) = setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(now) +maturityDate);

        assertEq(currency.balanceOf(address(borrower)), borrowAmount);

        uint nav = nftFeed.calcUpdateNAV();
        uint fv = nftFeed.futureValue(nftFeed.nftID(loan));

        // FV = 100 * 1.05^5 = 127.62815625
        assertEq(fv, 127.62815625 ether);

        // (FV/1.03^5) = 110.093;
        assertEq(nav, 110.093921369062927876 ether);

        assertEq(assessor.seniorDebt(), rmul(submission.seniorSupply+submission.juniorSupply, assessor.seniorRatio()));

        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 0);
        assertEq(seniorTokenPrice, ONE);

        return (loan, tokenId);
    }


}
