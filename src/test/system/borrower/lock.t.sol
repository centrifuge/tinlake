// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../base_system.sol";

contract LockTest is BaseSystemTest {

    function setUp() public {
        baseSetup();
        createTestUsers();
    }

    function lock(uint loanId, uint tokenId) public {
        borrower.lock(loanId);
        assertPostCondition(loanId, tokenId);
    }

    function assertPreCondition(uint loanId, uint tokenId) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
    }

    function assertPostCondition(uint loanId, uint tokenId) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf  nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
    }

    function testLockNFT() public {
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        assertPreCondition(loanId, tokenId);
        lock(loanId, tokenId);
    }

    function testFailLockNFTLoanNotIssued() public {
        (uint tokenId, ) = issueNFT(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        // loan not issued - random id
        uint loanId = 11;
        lock(loanId, tokenId);
    }

    function testFailLockNFTNoApproval() public {
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        // borrower does not approve shelf to take NFT
        lock(loanId, tokenId);
    }

    function testFailLockNFTNotNFTOwner() public {
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        // borrower transfers nftOwnership to random user / borrower still loanOwner
        transferNFT(borrower_, randomUser_, tokenId);
        lock(loanId, tokenId);
    }

    function testFailLockNFTNotLoanOwner() public {
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        // random user transfers nftOwnership to borrower / random user still loanOwner
        collateralNFT.transferFrom(randomUser_, borrower_, tokenId);
        // borrower tries to lock nft
        lock(loanId, tokenId);
    }

}
