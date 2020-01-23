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

import "../../system.sol";
import "../../users/borrower.sol";
import "../../users/admin.sol";
import "../../users/investor.sol";

contract WithdrawTest is SystemTest {

    Borrower borrower;
    address borrower_;
   
    AdminUser public admin;
    address admin_;

    Investor public juniorInvestor;
    address public juniorInvestor_;

    Borrower randomUser;
    address randomUser_;
        
    function setUp() public {
        baseSetup();
        // setup users
        borrower = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        borrower_ = address(borrower);

        randomUser = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        randomUser_ = address(randomUser);

        admin = new AdminUser(address(shelf), address(pile), address(ceiling), address(title), address(distributor));
        admin_ = address(admin);
        rootAdmin.relyBorrowAdmin(admin_);

        juniorInvestor = new Investor(address(juniorOperator), currency_, address(juniorERC20));
        juniorInvestor_ = address(juniorInvestor);
        WhitelistOperator juniorOperator = WhitelistOperator(address(juniorOperator));
        juniorOperator.relyInvestor(juniorInvestor_);
    }

    function withdraw(uint loanId, uint tokenId, uint amount, address usr) public {
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint juniorBalance = currency.balanceOf(address(junior));
        uint initialAvailable = add(shelfBalance, juniorBalance);
        uint initialRecipientBalance = currency.balanceOf(usr);
        uint initialLoanBalance = shelf.balances(loanId);
        uint initialTotalBalance = shelf.balance();
        borrower.withdraw(loanId, amount, usr);
        assertPostCondition(loanId, tokenId, amount, usr, initialAvailable, initialRecipientBalance, initialLoanBalance, initialTotalBalance);
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

    function assertPostCondition(uint loanId, uint tokenId, uint withdrawAmount, address recipient, uint initialAvailable, uint initialRecipientBalance, uint initialLoanBalance, uint initialTotalBalance) public {
        // assert: nft still locked, shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: available balance decreased
        assertEq(currency.balanceOf(address(shelf)), sub(initialAvailable, withdrawAmount));
        // assert: no money left in tranche reserve -> withdraw calls balance
        assertEq(currency.balanceOf(address(junior)), 0);
        // assert: borrower balance increased
        assertEq(currency.balanceOf(recipient), add(initialRecipientBalance, withdrawAmount));
        // assert: loan balance reduced
        assertEq(shelf.balances(loanId), sub(initialLoanBalance, withdrawAmount));
        // assert: total balance reduced
        assertEq(shelf.balance(), sub(initialTotalBalance, withdrawAmount));
    }

    function testWithdraw() public {
        uint loanAmount = 100 ether;
        uint investAmount = loanAmount;
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        assertPreCondition(loanId, tokenId, loanAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testWithdrawToOtherUserAccount() public {
        uint loanAmount = 100 ether;
        uint investAmount = mul(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        assertPreCondition(loanId, tokenId, loanAmount);
        // recipient not borrower account
        withdraw(loanId, tokenId, loanAmount, randomUser_);
    }

    function testWithdrawFromShelfHasFunds() public {
        uint loanAmount = 100 ether;
        uint investAmount = mul(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, borrower_);
        // transfer funds directly into the shelf, without calling tranche.supply()
        supplyFunds(investAmount, address(shelf));
        assertPreCondition(loanId, tokenId, loanAmount);
        // recipient not borrower account
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testPartialWithdraw() public {
        uint loanAmount = 100 ether;
        // just withdraw half of your loan balance
        uint withdrawAmount = div(loanAmount, 2);
        uint investAmount = mul(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        assertPreCondition(loanId, tokenId, withdrawAmount);
        // recipient not borrower account
        withdraw(loanId, tokenId, withdrawAmount, borrower_);
    }

    function testFailWithdrawNFTnotLocked() public {
        uint loanAmount = 100 ether;
        uint investAmount = loanAmount;
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // do not lock nft
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testFailWithdrawNotLoanOwner() public {
        uint loanAmount = 100 ether;
        uint investAmount = loanAmount;
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(randomUser_);
        // issue loan for borrower
        uint loanId = randomUser.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, randomUser_);
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, randomUser_);
        // junior investor puts money into tranche
        invest(investAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testFailLoanHasNoBalance() public {
        uint loanAmount = 100 ether;
        uint investAmount = loanAmount;
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // do not init Borrow & add loan balance 
        // junior investor puts money into tranche
        invest(investAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testFailWithdrawNotEnoughFundsAvailable() public {
        uint loanAmount = 100 ether;
        uint investAmount = div(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testFailWithdrawTwice() public {
        uint loanAmount = 100 ether;
        uint investAmount = loanAmount;
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, tokenId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        assertPreCondition(loanId, tokenId, loanAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    // helpers
    function lockNFT(uint loanId, address usr) public {
        Borrower(usr).approveNFT(collateralNFT, address(shelf));
        Borrower(usr).lock(loanId);
    } 

    function invest(uint amount) public {
        currency.mint(juniorInvestor_, amount);
        juniorInvestor.doSupply(amount);
    }

    function initBorrow(uint loanId, uint tokenId, uint amount, address usr) public {
        uint ceiling = amount;
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        // borrower borrows -> loan[balance] = amount
        Borrower(usr).borrow(loanId, amount);
    }
    
    // Helper to supply shelf or tranches with currency without using supply or repay, since these functions are usign balance internally.
    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(this), amount);
        currency.transferFrom(address(this), address(addr), amount);
    }
}