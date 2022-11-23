// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "./base_system.sol";
import "./users/borrower.sol";
import "./users/admin.sol";

contract ScenarioTest is BaseSystemTest {
    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
        baseSetup();
        createTestUsers();
        // setup hevm
        navFeed_ = NAVFeedLike(address(nftFeed));
    }

    // --- Tests ---
    function testBorrowTransaction() public {
        // collateralNFT value
        (uint256 nftPrice, uint256 riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        uint256 tokenId = collateralNFT.issue(borrower_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower issue loan
        uint256 loan = borrower.issue(collateralNFT_, tokenId);
        uint256 ceiling = navFeed_.ceiling(loan);

        borrower.approveNFT(collateralNFT, address(shelf));
        fundLender(ceiling);
        uint preBalance = currency.balanceOf(borrower_);
        borrower.borrowAction(loan, ceiling);
        checkAfterBorrow(tokenId, ceiling, preBalance);
    }

    function testBorrowAndRepay() public {
        (uint256 nftPrice, uint256 riskGroup) = defaultCollateral();
        borrowRepay(nftPrice, riskGroup);
    }

    function testMediumSizeLoans() public {
        (uint256 nftPrice, uint256 riskGroup) = defaultCollateral();
        nftPrice = 20000 ether;
        borrowRepay(nftPrice, riskGroup);
    }

    function testHighSizeLoans() public {
        (uint256 nftPrice, uint256 riskGroup) = defaultCollateral();
        nftPrice = 20000000 ether;
        borrowRepay(nftPrice, riskGroup);
    }

    function testRepayFullAmount() public {
        (uint256 loan, uint256 tokenId,) = setupOngoingLoan();

        hevm.warp(block.timestamp + 1 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint256 reserveShould = pile.debt(loan) + currReserveBalance();
        // close without defined amount
        borrower.doClose(loan);
        uint256 totalT = uint256(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, reserveShould);
    }

    function testLongOngoing() public {
        (uint256 loan, uint256 tokenId,) = setupOngoingLoan();

        // interest 5% per day 1.05^300 ~ 2273996.1286 chi
        hevm.warp(block.timestamp + 300 days);

        // borrower needs some currency to pay rate
        setupRepayReq();

        uint256 reserveShould = pile.debt(loan) + currReserveBalance();

        // close without defined amount
        borrower.doClose(loan);

        uint256 totalT = uint256(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, reserveShould);
    }

    function testMultipleBorrowAndRepay() public {
        uint256 nftPrice = 10 ether;
        uint256 riskGroup = 2;
        // uint rate = uint(1000000564701133626865910626);

        fundLender(1000 ether);
        uint256 tBorrower = 0;
        // borrow
        for (uint256 i = 1; i <= 10; i++) {
            nftPrice = i * 100;

            // create borrower collateral collateralNFT
            uint256 tokenId = collateralNFT.issue(borrower_);
            // collateralNFT whitelist
            uint256 loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
            uint256 ceiling = navFeed_.ceiling(i);

            borrower.approveNFT(collateralNFT, address(shelf));
            uint preBalance = currency.balanceOf(borrower_);
            borrower.borrowAction(loan, ceiling);
            tBorrower += ceiling;
            checkAfterBorrow(i, ceiling, preBalance);
        }

        // repay
        uint256 tTotal = currency.totalSupply();

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);

        uint256 reserveBalance = currency.balanceOf(address(reserve));
        for (uint256 i = 1; i <= 10; i++) {
            nftPrice = i * 100;
            uint256 ceiling = computeCeiling(riskGroup, nftPrice);
            // repay transaction
            borrower.repayAction(i, ceiling);

            reserveBalance += ceiling;
            checkAfterRepay(i, i, tTotal, reserveBalance);
        }
    }

    function testFailBorrowSameTokenIdTwice() public {
        // collateralNFT value
        (uint256 nftPrice, uint256 riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        uint256 tokenId = collateralNFT.issue(borrower_);
        // price nft and set risk
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower issue loans
        uint256 loan = borrower.issue(collateralNFT_, tokenId);
        uint256 ceiling = navFeed_.ceiling(loan);

        borrower.approveNFT(collateralNFT, address(shelf));
        uint preBalance = currency.balanceOf(borrower_);
        borrower.borrowAction(loan, ceiling);
        checkAfterBorrow(tokenId, ceiling, preBalance);

        // should fail
        borrower.borrowAction(loan, ceiling);
    }

    function testFailBorrowNonExistingToken() public {
        borrower.borrowAction(42, 100);
    }

    function testFailBorrowNotWhitelisted() public {
        collateralNFT.issue(borrower_);
        borrower.borrowAction(1, 100);
    }

    function testFailAdmitNonExistingcollateralNFT() public {
        // borrower issue loan
        uint256 loan = borrower.issue(collateralNFT_, 123);

        (uint256 nftPrice, uint256 riskGroup) = defaultCollateral();
        // price nft and set risk
        priceNFTandSetRisk(20, nftPrice, riskGroup);
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        borrower.borrowAction(loan, ceiling);
    }

    function testFailBorrowcollateralNFTNotApproved() public {
        defaultCollateral();
        uint256 tokenId = collateralNFT.issue(borrower_);
        // borrower issue loans
        uint256 loan = borrower.issue(collateralNFT_, tokenId);
        uint256 ceiling = navFeed_.ceiling(loan);
        borrower.borrowAction(loan, ceiling);
    }
}
