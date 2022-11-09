// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../base_system.sol";

contract CloseTest is BaseSystemTest {
    function setUp() public {
        baseSetup();
        createTestUsers();
    }

    function closeLoan(uint256 loanId, bytes32 lookupId) public {
        borrower.close(loanId);
        assertPostCondition(lookupId);
    }

    function assertPreCondition(uint256 loanId, uint256 tokenId, bytes32 lookupId) public view {
        // assert: borrower owner of loan or owner of nft
        assert(title.ownerOf(loanId) == borrower_ || collateralNFT.ownerOf(tokenId) == borrower_);
        // assert: loan has been issued
        assert(shelf.nftlookup(lookupId) > 0);
        // assert: nft not locked anymore
        assert(!shelf.nftLocked(loanId));
        // assert: loan has no open debt
        assert(pile.debt(loanId) == 0);
    }

    function assertPostCondition(bytes32 lookupId) public {
        // assert: nft + loan removed nftlookup
        assertEq(shelf.nftlookup(lookupId), 0);

        // loan burned => owner = address(0)
        // current title implementation reverts if loan owner => address(0)
    }

    function testCloseLoanOwner() public {
        (uint256 tokenId, bytes32 lookupId) = issueNFT(borrower_);
        uint256 loanId = borrower.issue(collateralNFT_, tokenId);
        // transfer nft to random user / borrower still loanOwner
        borrower.approveNFT(collateralNFT, address(this));
        collateralNFT.transferFrom(borrower_, randomUser_, tokenId);
        assertPreCondition(loanId, tokenId, lookupId);
        closeLoan(loanId, lookupId);
    }

    function testCloseLoanNFTOwner() public {
        (uint256 tokenId, bytes32 lookupId) = issueNFT(randomUser_);
        uint256 loanId = randomUser.issue(collateralNFT_, tokenId);
        // transfer nft to borrower / make borrower nftOwner
        randomUser.approveNFT(collateralNFT, address(this));
        collateralNFT.transferFrom(randomUser_, borrower_, tokenId);
        closeLoan(loanId, lookupId);
    }

    function testFailCloseLoanNoPermissions() public {
        (uint256 tokenId, bytes32 lookupId) = issueNFT(randomUser_);
        shelf.issue(collateralNFT_, tokenId);
        // borrower not loanOwner or nftOwner
        closeLoan(123, lookupId);
    }

    function testFailCloseLoanNotExisting() public {
        (, bytes32 lookupId) = issueNFT(borrower_);
        // loan not issued
        uint256 loanId = 10;
        closeLoan(loanId, lookupId);
    }

    function testFailCloseNFTLocked() public {
        (uint256 tokenId, bytes32 lookupId) = issueNFT(borrower_);
        uint256 loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        borrower.lock(loanId);
        closeLoan(loanId, lookupId);
    }

    function testFailCloseLoanHasDebt() public {
        uint256 nftPrice = 200 ether; // -> ceiling 100 ether
        uint256 riskGroup = 1; // -> 12% per year

        (uint256 loanId, uint256 tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        closeLoan(loanId, lookupId);
    }
}
