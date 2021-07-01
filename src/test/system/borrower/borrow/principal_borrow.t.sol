// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "../../base_system.sol";

contract PrincipalBorrowTest is BaseSystemTest {

    function setUp() public {
        baseSetup();
        createTestUsers();
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
    }

    function fundTranches(uint amount) public {
        defaultInvest(amount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
    }

    function borrow(uint loanId, uint tokenId, uint amount, uint fixedFee) public {
        uint initialTotalBalance = shelf.balance();
        uint initialLoanBalance = shelf.balances(loanId);
        uint initialLoanDebt = pile.debt(loanId);
        uint initialCeiling = nftFeed.ceiling(loanId);

        fundTranches(amount);
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

        hevm.warp(block.timestamp + 365 days); // expected debt after 1 year ~ 123.2 ether
        // assert interest also accrued on fixed fees 110
        assertEq(pile.debt(loanId)/10, 123200000000000000000/10);
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

        hevm.warp(block.timestamp + 365 days); // expected debt after 1 year 19.2 ether

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
