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

import "./base_system.sol";
import "./users/borrower.sol";
import "./users/admin.sol";

contract ScenarioTest is BaseSystemTest {
    Hevm public hevm;
    NFTFeedLike nftFeed_;

    function setUp() public {
        baseSetup();
        createTestUsers(false);
        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        nftFeed_ = NFTFeedLike(address(nftFeed));
    }

    // Checks
    function checkAfterBorrow(uint tokenId, uint tBalance) public {
        assertEq(currency.balanceOf(borrower_), tBalance);
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
    }

    function checkAfterRepay(uint loan, uint tokenId, uint tTotal, uint tLender) public {
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
        assertEq(pile.debt(loan), 0);
        assertEq(currency.balanceOf(borrower_), safeSub(tTotal, tLender));
        assertEq(currency.balanceOf(address(pile)), 0);
    }

    function setupLoan(uint tokenId, address collateralNFT_, uint nftPrice, uint riskGroup) public returns (uint) {
       
        // borrower issue loans
        uint loan = borrower.issue(collateralNFT_, tokenId);

        // price collateral and add to riskgroup
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);

        emit log_named_uint("id", loan);
        return loan;
    }

    function borrow(uint loan, uint tokenId, uint borrowAmount) public {
        borrower.approveNFT(collateralNFT, address(shelf));
        setupCurrencyOnLender(borrowAmount);
        borrower.borrowAction(loan, borrowAmount);
        checkAfterBorrow(tokenId, borrowAmount);
    }

    function defaultCollateral() public pure returns(uint nftPrice, uint riskGroup) {
        uint nftPrice = 100 ether;
        uint riskGroup = 2;
        return (nftPrice, riskGroup);
    }

    function setupOngoingLoan() public returns (uint loan, uint tokenId, uint ceiling) {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
        uint ceiling = nftFeed_.ceiling(loan);

        borrow(loan, tokenId, ceiling);

        return (loan, tokenId, ceiling);
    }

    function setupRepayReq() public returns(uint) {
        // borrower needs some currency to pay rate
        uint extra = 100000000000 ether;
        currency.mint(borrower_, extra);

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));

        return extra;
    }

    // note: this method will be refactored with the new lender side contracts, as the distributor should not hold any currency
    function currdistributorBal() public view returns(uint) {
        return currency.balanceOf(address(distributor));
    }

    function borrowRepay(uint nftPrice, uint riskGroup) public {
        // create borrower collateral collateralNFT
        uint tokenId = collateralNFT.issue(borrower_);
        uint loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
        uint ceiling = nftFeed_.ceiling(loan);

        assertEq(nftFeed_.ceiling(loan), ceiling);
        borrow(loan, tokenId, ceiling);
        assertEq(nftFeed_.ceiling(loan), 0);

        hevm.warp(now + 10 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint distributorShould = pile.debt(loan) + currdistributorBal();
        // close without defined amount
        borrower.doClose(loan);
        uint totalT = uint(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, distributorShould);
    }

    // --- Tests ---


    function testBorrowTransaction() public {
        // collateralNFT value
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        uint tokenId = collateralNFT.issue(borrower_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower issue loan
        uint loan =  borrower.issue(collateralNFT_, tokenId);
        uint ceiling = nftFeed_.ceiling(loan);

        borrower.approveNFT(collateralNFT, address(shelf));
        setupCurrencyOnLender(ceiling);
        borrower.borrowAction(loan, ceiling);
        checkAfterBorrow(tokenId, ceiling);
    }

    function testBorrowAndRepay() public {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        borrowRepay(nftPrice, riskGroup);
    }


    function testMediumSizeLoans() public {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        nftPrice = 20000 ether;
        borrowRepay(nftPrice, riskGroup);
    }

     function testHighSizeLoans() public {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        nftPrice = 20000000 ether;
        borrowRepay(nftPrice, riskGroup);
     }

    function testRepayFullAmount() public {
        (uint loan, uint tokenId,) = setupOngoingLoan();

        hevm.warp(now + 1 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint distributorShould = pile.debt(loan) + currdistributorBal();
        // close without defined amount
        borrower.doClose(loan);

        uint totalT = uint(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, distributorShould);
    }

    function testLongOngoing() public {
        (uint loan, uint tokenId, ) = setupOngoingLoan();

        // interest 5% per day 1.05^300 ~ 2273996.1286 chi
        hevm.warp(now + 300 days);

        // borrower needs some currency to pay rate
        setupRepayReq();

        uint distributorShould = pile.debt(loan) + currdistributorBal();

        // close without defined amount
        borrower.doClose(loan);

        uint totalT = uint(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, distributorShould);
    }

    function testMultipleBorrowAndRepay() public {
        uint nftPrice = 10 ether;
        uint riskGroup = 2;
        // uint rate = uint(1000000564701133626865910626);

        uint tBorrower = 0;
        // borrow
        for (uint i = 1; i <= 10; i++) {

            nftPrice = i * 100;

            // create borrower collateral collateralNFT
            uint tokenId = collateralNFT.issue(borrower_);
            // collateralNFT whitelist
            uint loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
            uint ceiling = nftFeed_.ceiling(i);
    
            borrower.approveNFT(collateralNFT, address(shelf));

            setupCurrencyOnLender(ceiling);
            borrower.borrowAction(loan, ceiling);
            tBorrower += ceiling;
            checkAfterBorrow(i, tBorrower);
        }

        // repay
        uint tTotal = currency.totalSupply();

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));

        uint distributorBalance = currency.balanceOf(address(distributor));
        for (uint i = 1; i <= 10; i++) {
            nftPrice = i * 100;
            uint ceiling = computeCeiling(riskGroup, nftPrice);
            // repay transaction
            borrower.repayAction(i, ceiling);

            distributorBalance += ceiling;
            checkAfterRepay(i, i, tTotal, distributorBalance);
        }
    }

    function testFailBorrowSameTokenIdTwice() public {
        // collateralNFT value
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        uint tokenId = collateralNFT.issue(borrower_);
        // price nft and set risk
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower issue loans
        uint loan =  borrower.issue(collateralNFT_, tokenId);
        uint ceiling = nftFeed_.ceiling(loan);

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, ceiling);
        checkAfterBorrow(tokenId, ceiling);

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
        uint loan =  borrower.issue(collateralNFT_, 123);

        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // price nft and set risk
        priceNFTandSetRisk(20, nftPrice, riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        borrower.borrowAction(loan, ceiling);
    }

    function testFailBorrowcollateralNFTNotApproved() public {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        uint tokenId = collateralNFT.issue(borrower_);
        // borrower issue loans
        uint loan =  borrower.issue(collateralNFT_, tokenId);
        uint ceiling = nftFeed_.ceiling(loan);
        borrower.borrowAction(loan, ceiling);
    }
}
