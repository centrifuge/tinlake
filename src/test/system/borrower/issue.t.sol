// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "../base_system.sol";

contract IssueTest is BaseSystemTest {

    function setUp() public {
        baseSetup();
        createTestUsers();
    }

    function issueLoan(uint tokenId, bytes32 lookupId) public {
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        assertPostCondition(loanId, tokenId, lookupId);
    }

    function assertPreCondition(uint tokenId, bytes32 lookupId) public {
        // assert: borrower = nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
        // assert: nft not used for other loan
        assertEq(shelf.nftlookup(lookupId), 0);
    }

    function assertPostCondition(uint loanId, uint tokenId, bytes32 lookupId) public {
        // assert: nft + loan added to nftlookup
        assertEq(shelf.nftlookup(lookupId), loanId);
        // assert: borrower = loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower still nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
    }

    function testIssueLoan() public {
        (uint tokenId, bytes32 lookupId) = issueNFT(borrower_);
        assertPreCondition(tokenId, lookupId);
        issueLoan(tokenId, lookupId);
    }

    function testFailIssueMultipleLoansForOneNFT() public {
        (uint tokenId, bytes32 lookupId) = issueNFT(borrower_);
        issueLoan(tokenId, lookupId);

        // issue second loan against same nft
        uint secondLoanId = borrower.issue(collateralNFT_, tokenId);
        assertPostCondition(secondLoanId, tokenId, lookupId);
    }

    function testFailIssueLoanNotNFTOwner() public {
        // issue nft for random user -> borrower != nftOwner
        (uint tokenId, bytes32 lookupId) = issueNFT(randomUser_);
        issueLoan(tokenId, lookupId);
    }
}
