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

import "../base_system.sol";

contract LockTest is BaseSystemTest {

    function setUp() public {
        baseSetup();
        createTestUsers(false);
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
