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
import "../users/admin.sol";

contract WithdrawTest is SystemTest {

    Borrower borrower;
    address borrower_;
   
    AdminUser public admin;
    address admin_;
        
    function setUp() public {
        baseSetup();
        // setup users
        borrower = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        borrower_ = address(borrower);

        admin = new AdminUser(address(shelf), address(pile), address(ceiling), address(title), address(distributor));
        admin_ = address(admin);

        rootAdmin.relyBorrowAdmin(admin_);
    }

    function withdraw(uint loanId, uint tokenId, uint amount, address usr) public {
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint juniorBalance = currency.balanceOf(address(junior));
        uint initialAvailable = add(shelfBalance, juniorBalance);
        uint initialBorrowerBalance = currency.balanceOf(borrower_);
        uint initialLoanBalance = shelf.balances(loanId);
        uint initialTotalBalance = shelf.balance();
        borrower.withdraw(loanId, amount, usr);
        assertPostCondition(loanId, tokenId, amount, usr, initialAvailable, initialBorrowerBalance, initialLoanBalance, initialTotalBalance);
    }

    function assertPreCondition(uint loanId, uint tokenId, uint amount) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: loan has enough balance 
        assert(shelf.balances(loanId) >= amount);
        // assert: enough funds available
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint juniorBalance = currency.balanceOf(address(junior));
        assert(add(shelfBalance, juniorBalance) >= amount);
    }


    function assertPostCondition(uint loanId, uint tokenId, uint withdrawAmount, address recipient, uint initialAvailable, uint initialBorrowerBalance, uint initialLoanBalance, uint initialTotalBalance) public {
        // assert: nft still locked, shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: available balance decreased
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint juniorBalance = currency.balanceOf(address(junior));
        assertEq(add(shelfBalance, juniorBalance), sub(initialAvailable, withdrawAmount));
        // assert: borrower balance increased
        assertEq(currency.balanceOf(borrower_), add(initialBorrowerBalance, withdrawAmount));
        // assert: loan balance reduced
        assertEq(shelf.balances(loanId), sub(initialLoanBalance, withdrawAmount));
        // assert: total balance reduced
        assertEq(shelf.balance(), sub(initialTotalBalance, withdrawAmount));
    }

    function testWithdraw() public {
        uint loanAmount = 100 ether;
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId);
        initBorrow
        


    }
    function testWithdrawToOtherUserAccount() public {}
    function testWithdrawTransferFundsFromLender() public {}
    function testPartialWithdraw() public {}
    function testFailWithdrawNFTnotLocked() public {}
    function testFailWithdrawNotLoanOwner() public {}
    function testFailLoanHasNoBalance() public {}
    function testFailWithdrawNotEnoughFundsShelf() public {}
    function testFailWithdrawNotEnoughFundsLender() public {}

    // helpers
    function lockNFT(uint loanId) public {
        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.lock(loanId);
    } 

    function initBorrow(uint amount) public {
        uint ceiling = amount;
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        // borrower borrows -> loan[balance] > 0
        borrower.borrow(loanId, tokenId, amount);
    }

    // Helper to supply shelf or tranches with currency without using supply or repay, since these functions are usign balance internally.
    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(this), amount);
        currency.transferFrom(address(this), address(addr), amount);
    }
}