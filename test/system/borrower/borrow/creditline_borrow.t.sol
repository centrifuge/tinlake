// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../../base_system.sol";

contract CreditLineBorrowTest is BaseSystemTest {
    function setUp() public {
        baseSetup();
        createTestUsers();
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
    }

    function fundTranches(uint256 amount) public {
        defaultInvest(amount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
    }

    function borrow(uint256 loanId, uint256 tokenId, uint256 amount, uint256 fixedFee) public {
        uint256 initialTotalBalance = shelf.balance();
        uint256 initialLoanBalance = shelf.balances(loanId);
        uint256 initialLoanDebt = pile.debt(loanId);
        uint256 initialCeiling = nftFeed.ceiling(loanId);
        uint256 initialNAV = nftFeed.currentNAV();

        fundTranches(amount);
        borrower.borrow(loanId, amount);
        assertPostCondition(
            loanId,
            tokenId,
            amount,
            fixedFee,
            initialTotalBalance,
            initialLoanBalance,
            initialLoanDebt,
            initialCeiling,
            initialNAV
        );
    }

    function assertPreCondition(uint256 loanId, uint256 tokenId, uint256 amount) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrowAmount <= ceiling
        assert(amount <= nftFeed.ceiling(loanId));
    }

    function assertPostCondition(
        uint256 loanId,
        uint256 tokenId,
        uint256 amount,
        uint256 fixedFee,
        uint256 initialTotalBalance,
        uint256 initialLoanBalance,
        uint256 initialLoanDebt,
        uint256 initialCeiling,
        uint256 initialNAV
    ) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));

        // assert: totalBalance increase by borrow amount
        assertEq(shelf.balance(), safeAdd(initialTotalBalance, amount));

        // assert: loanBalance increase by borrow amount
        assertEq(shelf.balances(loanId), safeAdd(initialLoanBalance, amount));

        // assert: loanDebt increased by borrow amount +/- 1 roundign tolerance
        uint256 newDebtExpected = safeAdd(initialLoanDebt, safeAdd(amount, fixedFee));
        uint256 newDebtActual = pile.debt(loanId);
        assert((safeSub(newDebtActual, 1) <= newDebtExpected) && (newDebtExpected <= safeAdd(newDebtExpected, 1)));

        // assert: available borrow amount decreased
        assertEq(nftFeed.ceiling(loanId), safeSub(initialCeiling, amount));

        // assert: NAV
        emit log_named_uint("initial", initialNAV);
        emit log_named_uint("amount", amount);
        emit log_named_uint("fixedFee", fixedFee);

        assertEq(nftFeed.currentNAV(), safeAdd(initialNAV, safeAdd(amount, fixedFee)));
    }

    function testMultipleBorrow() public {
        fundTranches(1000000000 ether);
        for (uint256 i = 1; i <= 10; i++) {
            uint256 nftPrice = 2000 ether;
            uint256 riskGroup = 1; // creditline 1000 eth

            (uint256 tokenId, uint256 loanId) = issueNFTAndCreateLoan(borrower_);
            // price nft
            priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
            uint256 ceiling = computeCeiling(riskGroup, nftPrice);
            // lock nft for borrower
            lockNFT(loanId, borrower_);
            // set ceiling based tokenPrice & riskgroup
            assertPreCondition(loanId, tokenId, ceiling);
            borrower.borrow(loanId, ceiling);
        }

        assertEq(nftFeed.currentNAV(), pile.debt(1) * 10);
        hevm.warp(block.timestamp + 365 days); // ~ debt 1120 ether per loan
        assertEq(nftFeed.currentNAV(), pile.debt(1) * 10);
    }

    function testBorrow() public {
        uint256 nftPrice = 500 ether;
        uint256 riskGroup = 0;

        (uint256 tokenId, uint256 loanId) = issueNFTAndCreateLoan(borrower_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        // lock nft for borrower
        lockNFT(loanId, borrower_);
        // set ceiling based tokenPrice & riskgroup

        assertPreCondition(loanId, tokenId, ceiling);
        borrow(loanId, tokenId, ceiling, 0);
    }

    function testPartialBorrow() public {
        uint256 nftPrice = 200 ether;
        uint256 riskGroup = 0;

        (uint256 tokenId, uint256 loanId) = issueNFTAndCreateLoan(borrower_);

        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        // borrow amount smaller then ceiling
        uint256 amount = safeDiv(ceiling, 2);

        lockNFT(loanId, borrower_);
        assertPreCondition(loanId, tokenId, amount);
        borrow(loanId, tokenId, amount, 0);
    }

    function testFailPartialBorrowWithInterest() public {
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 borrowAmount = 16 ether; // -> rest 34 ether
        uint256 riskGroup = 1; // -> 12% per year
        (uint256 tokenId, uint256 loanId) = issueNFTAndCreateLoan(borrower_); // interest starts ticking

        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        uint256 rest = safeSub(ceiling, borrowAmount);

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
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 amount = computeCeiling(riskGroup, nftPrice);

        (uint256 tokenId, uint256 loanId) = issueNFTAndCreateLoan(borrower_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        borrow(loanId, tokenId, amount, 0);
    }

    function testFailBorrowNotLoanOwner() public {
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether

        uint256 riskGroup = 1; // -> 12% per year
        uint256 amount = computeCeiling(riskGroup, nftPrice);
        (uint256 tokenId, uint256 loanId) = issueNFTAndCreateLoan(randomUser_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);

        // lock nft for random user
        randomUser.lock(loanId);
        // borrower tries to borrow against loan
        borrow(loanId, tokenId, amount, 0);
    }

    function testFailBorrowAmountTooHigh() public {
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        uint256 amount = safeMul(ceiling, 2);
        (uint256 tokenId, uint256 loanId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        borrow(loanId, tokenId, amount, 0);
    }
}
