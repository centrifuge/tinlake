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

import "../base_system.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "../../../lender/test/coordinator-base.t.sol";

contract LenderSystemTest is BaseSystemTest, BaseTypes, Interest {
    Hevm public hevm;

    function setUp() public {
        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        baseSetup();
        createTestUsers();
        nftFeed_ = NFTFeedLike(address(nftFeed));

    }

    function seniorSupply(uint currencyAmount) public {
        currency.mint(address(seniorInvestor), currencyAmount);
        admin.makeSeniorTokenMember(seniorInvestor_, safeAdd(now, 8 days));
        seniorInvestor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = seniorTranche.users(seniorInvestor_);
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

    function testSupplyClose() public {
        uint seniorSupplyAmount = 82 ether;
        uint juniorSupplyAmount = 18 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(now + 1 days);

        closeEpoch(true);
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
        (uint loan, uint tokenId) = setupOngoingLoan(nftPrice, borrowAmount, false, nftFeed.uniqueDayTimestamp(now) +maturityDate);

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


    function testSupplyAndBorrow() public {
        uint seniorSupplyAmount = 500 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 82 ether,
            juniorSupply : 18 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);

    }

    function calcInterest(uint amount, uint time, uint ratePerSecond) public returns(uint) {
        return rmul(rpow(ratePerSecond, time, ONE), amount);
    }

    function testLenderScenarioA() public {
        uint seniorSupplyAmount = 500 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;


        ModelInput memory submission = ModelInput({
            seniorSupply : 82 ether,
            juniorSupply : 18 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);

        // time impact on token senior token price
        hevm.warp(now + 1 days);

        // additional senior debt increase for one day
        // 82 * 1.02 ~ 83.64
        assertEq(assessor.seniorDebt(), calcInterest(submission.seniorSupply, 24 hours, assessor.seniorInterestRate()));


        uint nav = nftFeed.calcUpdateNAV();

        //(FV/1.03^4) = 127.62815625 /(1.03^4) = 113.395963777
        assertEq(nav, 113.39 ether, TWO_DECIMAL_PRECISION);

        // should be 83.64/82 = 83.64/82= 1.02
        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 0);
        assertEq(seniorTokenPrice, fixed18To27(1.02 ether), FIXED27_TWO_DECIMAL_PRECISION);


        // seniorRatio should be still the old one
        assertEq(assessor.seniorRatio(), fixed18To27(0.82 ether));

        // new orders
        // first investors need to disburse
        seniorSupplyAmount = 80 ether;
        juniorSupplyAmount = 20 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        // minimum epoch should be already reached
        coordinator.closeEpoch();
        // epoch should be executed no submission required
        assertTrue(coordinator.submissionPeriod() == false);

        // seniorSupply and juniorSupply should be now in reserve
        assertEq(reserve.totalBalance(), 100 ether);

        // nav should be still the same
        uint preNAV = nftFeed.calcUpdateNAV();
         nav = nftFeed.calcUpdateNAV();

        // nav= 113.39 ether
        assertEq(nav, preNAV);

        // seniorAsset: seniorDebt + seniorBalance =  83.64 + 80 ~ 163.64
        // NAV + reserve ~ 213.39
        // seniorRatio: 163.64/213.139 ~ 0.76
        uint shouldSeniorRatio = rdiv(assessor.seniorDebt() + assessor.seniorBalance(), nav + reserve.totalBalance());

        assertEq(coordinator.epochNAV(), nav, TWO_DECIMAL_PRECISION);
        assertEq(coordinator.epochSeniorAsset(), 83.64 ether, TWO_DECIMAL_PRECISION);
        assertEq(assessor.seniorRatio(), shouldSeniorRatio);
        assertEq(assessor.seniorRatio(), fixed18To27(0.76 ether), FIXED27_TWO_DECIMAL_PRECISION);

        // check reBalancing
        assertEq(assessor.seniorDebt(), rmul(nav, shouldSeniorRatio));
        assertEq(assessor.seniorBalance(), coordinator.epochSeniorAsset()+seniorSupplyAmount - rmul(nav, shouldSeniorRatio));
    }

    function testAutomaticReSupply() public {
        uint seniorSupplyAmount = 1000 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        uint borrowAmount = 100 ether;
        uint maturityDate =  5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 80 ether,
            juniorSupply : 20 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate,  submission);

        hevm.warp(now + 1 days);
        juniorSupplyAmount = 180 ether;

        juniorSupply(juniorSupplyAmount);

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == false);

         assertEq(seniorToken.balanceOf(seniorInvestor_), 80 ether);
        // senior

        (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) = seniorTranche.calcDisburse(seniorInvestor_);

        assertEq(payoutTokenAmount, seniorToken.balanceOf(address(seniorTranche)));
        assertEq(remainingSupplyCurrency, 0);

        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) = seniorInvestor.disburse();

        // 80 ether token from previous supply/redeem
        assertEq(seniorToken.balanceOf(seniorInvestor_), safeAdd(payoutTokenAmount, 80 ether));

        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nftFeed.approximatedNAV(), reserve.totalBalance());
        uint juniorTokenPrice = assessor.calcJuniorTokenPrice(nftFeed.approximatedNAV(), reserve.totalBalance());

        // ongoing loan has 5 % interest, senior wants 2% interest therefore 3%  left for junior
        // juniorAssetValue increased more than seniorAssetValue therefore higher juniorTokenPrice
        assertTrue(juniorTokenPrice > seniorTokenPrice);

        assertEq(nftFeed.approximatedNAV() + reserve.totalBalance(), rmul(seniorTranche.tokenSupply(),seniorTokenPrice) + rmul(juniorTranche.tokenSupply(),juniorTokenPrice), 10);
    }

    function testLoanRepayments() public {
        uint seniorSupplyAmount = 1000 ether;
        uint juniorSupplyAmount = 20 ether;
        uint nftPrice = 200 ether;
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 80 ether,
            juniorSupply : 20 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        (uint loan, uint tokenId) = supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);

        // remove existing order
        seniorSupply(0);

        hevm.warp(now + 1 days);

        uint nav = nftFeed.calcUpdateNAV();

        //(FV/1.03^4) = 127.62815625 /(1.03^4) = 113.395963777
        assertEq(nav, 113.39 ether, TWO_DECIMAL_PRECISION);

        assertEq(reserve.totalBalance(), 0);

        uint loanDebt = pile.debt(loan);
        repayLoan(address(borrower), loan, loanDebt);

        assertEq(reserve.totalBalance(), loanDebt);
        assertEq(nftFeed.approximatedNAV(), 0);

        // max redeem from both

        seniorInvestor.redeemOrder(seniorToken.balanceOf(seniorInvestor_));
        juniorInvestor.redeemOrder(seniorToken.balanceOf(juniorInvestor_));

        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == true);
    }
}

