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

contract UnlockTest is SystemTest {

    Hevm public hevm;

    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_);
        createTestUsers();

        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
    }
    
    function unlockNFT(uint loanId, uint tokenId) public {
        borrower.unlock(loanId);
        assertPostCondition(loanId, tokenId);
    }

    function assertPreCondition(uint loanId, uint tokenId) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: nft locked = shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert loan has no open debt
        assertEq(pile.debt(loanId), 0);
    }

    function assertPostCondition(uint loanId, uint tokenId) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: nft unlocked = ownership transferred back to borrower
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
    }

    function testUnlockNFT() public {
        (uint tokenId, ) = issueNFT(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        // issue loan
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        assertPreCondition(loanId, tokenId);
        unlockNFT(loanId, tokenId);
    }

    function testUnlockNFTAfterRepay() public {
        uint amount = 100 ether;
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // borrow
        borrow(loanId, amount);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
         //repay after 1 year
        hevm.warp(now + 365 days);
        // loan category 0 -> no accrued interest
        borrower.repay(loanId, amount);
        assertPreCondition(loanId, tokenId);
        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockNotLoanOwner() public {
        (uint tokenId, ) = issueNFT(randomUser_);
        randomUser.approveNFT(collateralNFT, address(shelf));
        // issue loan
        uint loanId = randomUser.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, randomUser_);
        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockOpenDebt() public {
        uint amount = 100 ether;
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // borrow
        borrow(loanId, amount);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
         //repay after 1 year
        hevm.warp(now + 365 days);
        // do not repay loan
        unlockNFT(loanId, tokenId);
    }

    // helper
    function borrow(uint loanId, uint amount) public {
        uint investAmount = amount;
         // investor invests into tranche
        invest(investAmount);
        // admin sets parameters for the loan
        admin.setCeiling(loanId, amount);
        // borrower borrows funds
        borrower.borrow(loanId, amount);
        borrower.withdraw(loanId, amount, borrower_);        
    }

    function lockNFT(uint loanId, address usr) public {
        Borrower(usr).approveNFT(collateralNFT, address(shelf));
        Borrower(usr).lock(loanId);
    } 

    function invest(uint amount) public {
        currency.mint(juniorInvestor_, amount);
        juniorInvestor.doSupply(amount);
    }
}