// Copyright (C) 2019 Centrifuge

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

contract PrincipalBorrowTest is BaseSystemTest {

    Hevm public hevm;

    function setUp() public {
        baseSetup();
        createTestUsers();
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        invest(defaultAmount);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();
    }

    function borrow(uint loanId, uint tokenId, uint amount, uint fixedFee) public {
        uint initialTotalBalance = shelf.balance();
        uint initialLoanBalance = shelf.balances(loanId);
        uint initialLoanDebt = pile.debt(loanId);
        uint initialCeiling = nftFeed.ceiling(loanId);

        borrower.borrow(loanId, amount);
        assertPostCondition(loanId, tokenId, amount, fixedFee, initialTotalBalance, initialLoanBalance, initialLoanDebt, initialCeiling);
    }

    function assertPreCondition(uint loanId, uint tokenId, uint amount) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrowAmount <= ceiling
        assert(amount <= nftFeed.ceiling(loanId));
    }

    function assertPostCondition(uint loanId, uint tokenId, uint amount, uint fixedFee, uint initialTotalBalance, uint initialLoanBalance,  uint initialLoanDebt, uint initialCeiling) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));

        // assert: totalBalance increase by borrow amount
        assertEq(shelf.balance(), safeAdd(initialTotalBalance, amount));

        // assert: loanBalance increase by borrow amount
        assertEq(shelf.balances(loanId), safeAdd(initialLoanBalance, amount));

        // assert: loanDebt increased by borrow amount +/- 1 roundign tolerance
        uint newDebtExpected = safeAdd(initialLoanDebt, safeAdd(amount, fixedFee));
        uint newDebtActual = pile.debt(loanId);
        assert((safeSub(newDebtActual, 1) <= newDebtExpected) && (newDebtExpected <= safeAdd(newDebtExpected , 1)));

        // assert: available borrow amount decreased
        assertEq(nftFeed.ceiling(loanId), safeSub(initialCeiling, amount));
    }

    function testBorrow() public {
        uint nftPrice = 500 ether;
        uint riskGroup = 0;

        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        // lock nft for borrower
        lockNFT(loanId, borrower_);
        // set ceiling based tokenPrice & riskgroup

        assertPreCondition(loanId, tokenId, ceiling);
        borrow(loanId, tokenId, ceiling, 0);
    }

    function testBorrowWithFixedFee() public {
        uint nftPrice = 500 ether;
        uint riskGroup = 0;
        uint fixedFeeRate = 10**26; // 10 %

        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        uint borrowAmount = computeCeiling(riskGroup, nftPrice); // borrowAmount equals ceiling
        uint fixedFee = rmul(borrowAmount, fixedFeeRate); // fixed fee that has to be applied on the borrowAmount

        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // set fixed fee for rateGroup
        admin.fileFixedRate(riskGroup, fixedFeeRate);
        // lock nft for borrower
        lockNFT(loanId, borrower_);

        assertPreCondition(loanId, tokenId, borrowAmount);
        borrow(loanId, tokenId, borrowAmount, fixedFee);
    }

    function testInterestAccruedOnFixedFee() public {
        uint nftPrice = 200 ether;
        uint riskGroup = 1;
        uint fixedFeeRate = 10**26; // 10 %

        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        uint borrowAmount = computeCeiling(riskGroup, nftPrice); // ceiling => 50 % => 100 ether
        uint fixedFee = rmul(borrowAmount, fixedFeeRate); // fixed fee = 10 % => 10 ether
        
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // set fixed fee for rateGroup
        admin.fileFixedRate(riskGroup, fixedFeeRate);
        // lock nft for borrower
        lockNFT(loanId, borrower_);

        assertPreCondition(loanId, tokenId, borrowAmount);
        borrow(loanId, tokenId, borrowAmount, fixedFee);

        hevm.warp(now + 365 days); // expected debt after 1 year ~ 123.2 ether
        // assert interest also accrued on fixed fees 110 
        assertEq(pile.debt(loanId), 123200000000000000001);
    }

    function testPartialBorrow() public {
        uint nftPrice = 200 ether;
        uint riskGroup = 0;

        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);

        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);
         // borrow amount smaller then ceiling
        uint amount = safeDiv(ceiling , 2);

        lockNFT(loanId, borrower_);
        assertPreCondition(loanId, tokenId, amount);
        borrow(loanId, tokenId, amount, 0);
    }

    function testFailPartialBorrowWithInterest() public {
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint borrowAmount = 16 ether; // -> rest 34 ether
        uint riskGroup = 1; // -> 12% per year
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_); // interest starts ticking
        
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        uint rest = safeSub(ceiling, borrowAmount);

        // lock nft for borrower
        lockNFT(loanId, borrower_);
        assertPreCondition(loanId, tokenId, borrowAmount);

        // borrower borrows a chunk of the ceiling
        borrow(loanId, tokenId, borrowAmount, 0);

        hevm.warp(now + 365 days); // expected debt after 1 year 19.2 ether

        // borrowing the amount left should fail because the accrued debt lowered the ceiling
        borrow(loanId, tokenId, rest, 0);
    }

    function testFailBorrowNFTNotLocked() public {
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint amount = computeCeiling(riskGroup, nftPrice);

        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        borrow(loanId, tokenId, amount, 0);
    }

    function testFailBorrowNotLoanOwner() public {
        uint nftPrice = 100 ether; // -> ceiling 50 ether

        uint riskGroup = 1; // -> 12% per year
        uint amount = computeCeiling(riskGroup, nftPrice);
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(randomUser_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);

        // lock nft for random user
        randomUser.lock(loanId);
        // borrower tries to borrow against loan
        borrow(loanId, tokenId, amount, 0);
    }

    function testFailBorrowAmountTooHigh() public {
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        uint amount = safeMul(ceiling, 2);
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        borrow(loanId, tokenId, amount, 0);
    }
}
