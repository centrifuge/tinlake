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

pragma solidity >=0.5.12;

import "../system.sol";
import "../users/borrower.sol";

contract LockTest is SystemTest {

    Borrower borrower;
    address borrower_;

    Borrower randomUser;
    address randomUser_;

    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_);
        borrower = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        borrower_ = address(borrower);
        randomUser = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        randomUser_ = address(randomUser);
    }
    
    function lockNFT(uint loanId, uint tokenId) public {
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
        (uint tokenId, ) = issueNFT(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        assertPreCondition(loanId, tokenId);
        lockNFT(loanId, tokenId);
    }

    function testFailLockNFTLoanNotIssued() public {
        (uint tokenId, ) = issueNFT(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        // loan not issued - random id
        uint loanId = 11;
        lockNFT(loanId, tokenId);
    }

    function testFailLockNFTNoApproval() public {
        (uint tokenId, ) = issueNFT(randomUser_);
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        lockNFT(loanId, tokenId);
    }

    function testFailLockNFTNotNFTOwner() public {
        (uint tokenId, ) = issueNFT(borrower_);
        // borrower creates loan against nft
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // borrower transfers nftOwnership to random user / borrower still loanOwner
        borrower.approveNFT(collateralNFT, address(this));
        collateralNFT.transferFrom(borrower_, randomUser_, tokenId);
        // nftOwner approves shelf to lock
        collateralNFT.setApprovalForAll(address(shelf), true);
        // borrower tries to lock nft
        lockNFT(loanId, tokenId);
    }

    function testFailLockNFTNotLoanOwner() public {
        (uint tokenId, ) = issueNFT(randomUser_);
        // random user creates loan against nft
        uint loanId = randomUser.issue(collateralNFT_, tokenId);
        // random user transfers nftownership to borrower / random user still loanOwner
        collateralNFT.transferFrom(randomUser_, borrower_, tokenId);
        borrower.approveNFT(collateralNFT, address(shelf));
        // nftOwner approves shelf to lock
        collateralNFT.setApprovalForAll(address(shelf), true);
        // borrower tries to lock nft
        lockNFT(loanId, tokenId);
    }

}