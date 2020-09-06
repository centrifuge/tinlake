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

import "../../base_system.sol";

contract PrincipalRepayTest is BaseSystemTest {
    Hevm public hevm;

    function setUp() public {
        baseSetup();
        createTestUsers();

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        fundTranches();
    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        invest(defaultAmount);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();
    }

    function repay(uint loanId, uint tokenId, uint amount, uint expectedDebt) public {
        uint initialBorrowerBalance = currency.balanceOf(borrower_);
        uint initialTrancheBalance = currency.balanceOf(address(reserve));
        uint initialCeiling = nftFeed.ceiling(loanId);
        borrower.repay(loanId, amount);
        assertPostCondition(loanId, tokenId, amount, initialBorrowerBalance, initialTrancheBalance, expectedDebt, initialCeiling);
    }

    function assertPreCondition(uint loanId, uint tokenId, uint repayAmount, uint expectedDebt) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: loan has no open balance
        assertEq(shelf.balances(loanId), 0);
        // assert: loan has open debt
        assert(pile.debt(loanId) > 0);
        // assert: debt includes accrued interest (tolerance +/- 1)
        assertEq(pile.debt(loanId), expectedDebt, 10);
        // assert: borrower has enough funds
        assert(currency.balanceOf(borrower_) >= repayAmount);

    }

    function assertPostCondition(uint loanId, uint tokenId, uint repaidAmount, uint initialBorrowerBalance, uint initialTrancheBalance, uint expectedDebt, uint initialCeiling) public {
        // assert: borrower still loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf still nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrower funds decreased by the smaller of repaidAmount or totalLoanDebt
        if (repaidAmount > expectedDebt) {
            // make sure borrower did not pay more then hs debt
            repaidAmount = expectedDebt;

        }
        uint newBorrowerBalance = safeSub(initialBorrowerBalance, repaidAmount);
        assert(safeSub(newBorrowerBalance, currency.balanceOf(borrower_)) <= 1); // (tolerance +/- 1)
        // assert: shelf/tranche received funds
        // since we are calling balance inside repay, money is directly transferred to the tranche through shelf
        uint newTrancheBalance = safeAdd(initialTrancheBalance, repaidAmount);
        assertEq(currency.balanceOf(address(reserve)), newTrancheBalance, 10); // (tolerance +/- 1)
        // assert: debt amounts reduced by repayAmount (tolerance +/- 1)
        uint newDebt = safeSub(expectedDebt, repaidAmount);
        assert(safeSub(pile.debt(loanId), newDebt) <= 1);
        // aseert: initialCeiling did not increase
        assertEq(initialCeiling, nftFeed.ceiling(loanId));
    }

    function borrowAndRepay(address usr, uint nftPrice, uint riskGroup, uint expectedDebt, uint repayAmount) public {
        (uint loanId, uint tokenId) = createLoanAndWithdraw(usr, nftPrice, riskGroup);
        // supply borrower with additional funds to pay for accrued interest
        topUp(usr);
        // borrower allows shelf full control over borrower tokens
        Borrower(usr).doApproveCurrency(address(shelf), uint(-1));
        //repay after 1 year
        hevm.warp(now + 365 days);
        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
      //  repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testRepayFullDebt() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        borrowAndRepay(borrower_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testRepayMaxLoanDebt() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        // borrower tries to repay twice his debt amount
        uint repayAmount = safeMul(expectedDebt, 2);
        borrowAndRepay(borrower_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testPartialRepay() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = safeDiv(expectedDebt, 2);
        borrowAndRepay(borrower_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testRepayDebtNoRate() public {
        uint nftPrice = 100 ether; // -> ceiling 100 ether
        uint riskGroup = 0; // -> no interest rate
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice); // 60 %
        // expected debt after 1 year of compounding
        uint expectedDebt =  60 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        //repay after 1 year
        hevm.warp(now + 365 days);
        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayNotLoanOwner() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;

         // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        borrowAndRepay(randomUser_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testFailRepayNotEnoughFunds() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        hevm.warp(now + 365 days);

        // do not supply borrower with additional funds to repay interest

        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayLoanNotFullyWithdrawn() public {
       uint nftPrice = 200 ether; // -> ceiling 100 ether
       uint riskGroup = 1; // -> 12% per year
       uint rate = getRateByRisk(riskGroup);
       uint ceiling = computeCeiling(riskGroup, nftPrice); // 50% 100 ether
       uint borrowAmount = ceiling;
       uint withdrawAmount = safeSub(ceiling, 2); // half the borrowAmount
       uint repayAmount = ceiling;
       uint expectedDebt = 56 ether; // borrowamount + interest

       (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        // lock nft
        lockNFT(loanId, borrower_);
        // priceNFT
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower add loan balance of full ceiling
        borrower.borrow(loanId, borrowAmount);
        // borrower just withdraws half of ceiling -> loanBalance remains
        borrower.withdraw(loanId, withdrawAmount, borrower_);
        hevm.warp(now + 365 days);

        // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayZeroDebt() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        // lock nft
        lockNFT(loanId, borrower_);
         // priceNFT
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);

        // borrower does not borrow

        // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayCurrencyNotApproved() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        //repay after 1 year
        hevm.warp(now + 365 days);

         // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailBorowFullAmountTwice() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        uint rate = getRateByRisk(riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;

        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        //repay after 1 year
        hevm.warp(now + 365 days);
        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
        repay(loanId, tokenId, repayAmount, expectedDebt);

        // should fail -> principal = 0
        borrower.borrow(loanId, ceiling);
    }
}
