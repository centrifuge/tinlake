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

contract BorrowTest is SystemTest {

    Borrower borrower;
    address borrower_;
        
    function setUp() public {
        baseSetup();
        borrower = new Borrower(address(borrowerDeployer.shelf()), address(lenderDeployer.distributor()), currency_, address(borrowerDeployer.pile()));
        borrower_ = address(borrower);
    }
    
    function borrow(uint loanId, uint amount) public {
        borrower.borrow(loanId);
        assertPostCondition(loanId, amount);
    }

    function assertPreCondition(uint loanId, uint amount) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrowAmount <= ceiling
        assertEq()
    }

    function assertPostCondition(uint loanId, uint tokenId) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf  nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
    }

    function testBorrow() public {
        (uint tokenId, ) = issueNFT(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        assertPreCondition(loanId, tokenId, lookupId);
        lockNFT(loanId, tokenId);
    }

    function testFailLockNFTLoanNotIssued() public {
    }

    function testFailLockNFTNoApproval() public {
    }

    function testFailLockNFTBorrowerNotNFTOwner() public {
    }

    function testFailLockNFTBorrowerNotLoanOwner() public {
    }

}