// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../base_system.sol";

contract IssueTest is BaseSystemTest {
    function setUp() public {
        baseSetup();
        createTestUsers();
    }

    function issueLoan(uint256 tokenId, bytes32 lookupId) public {
        uint256 loanId = borrower.issue(collateralNFT_, tokenId);
        assertPostCondition(loanId, tokenId, lookupId);
    }

    function assertPreCondition(uint256 tokenId, bytes32 lookupId) public {
        // assert: borrower = nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
        // assert: nft not used for other loan
        assertEq(shelf.nftlookup(lookupId), 0);
    }

    function assertPostCondition(uint256 loanId, uint256 tokenId, bytes32 lookupId) public {
        // assert: nft + loan added to nftlookup
        assertEq(shelf.nftlookup(lookupId), loanId);
        // assert: borrower = loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower still nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
    }

    function testIssueLoan() public {
        (uint256 tokenId, bytes32 lookupId) = issueNFT(borrower_);
        assertPreCondition(tokenId, lookupId);
        issueLoan(tokenId, lookupId);
    }

    function testFailIssueMultipleLoansForOneNFT() public {
        (uint256 tokenId, bytes32 lookupId) = issueNFT(borrower_);
        issueLoan(tokenId, lookupId);

        // issue second loan against same nft
        uint256 secondLoanId = borrower.issue(collateralNFT_, tokenId);
        assertPostCondition(secondLoanId, tokenId, lookupId);
    }

    function testFailIssueLoanNotNFTOwner() public {
        // issue nft for random user -> borrower != nftOwner
        (uint256 tokenId, bytes32 lookupId) = issueNFT(randomUser_);
        issueLoan(tokenId, lookupId);
    }
}
