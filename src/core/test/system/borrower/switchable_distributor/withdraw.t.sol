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

contract WithdrawTest is SystemTest {

    SwitchableDistributor distributor;
        
    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_);
        createTestUsers();
        distributor = SwitchableDistributor(address(lenderDeployer.distributor()));
    }

    function withdraw(uint loanId, uint tokenId, uint amount, address usr) public {
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint juniorBalance = currency.balanceOf(address(junior));
        uint initialAvailable = safeAdd(shelfBalance, juniorBalance);
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
        assert(safeAdd(shelfBalance, juniorBalance) >= amount);
    }

    function assertPostCondition(uint loanId, uint tokenId, uint withdrawAmount, address recipient, uint initialAvailable, uint initialRecipientBalance, uint initialLoanBalance, uint initialTotalBalance) public {
        // assert: nft still locked, shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: available balance decreased
        assertEq(currency.balanceOf(address(shelf)), safeSub(initialAvailable, withdrawAmount));
        // assert: no money left in tranche reserve -> withdraw calls balance
        assertEq(currency.balanceOf(address(junior)), 0);
        // assert: borrower balance increased
        assertEq(currency.balanceOf(recipient), safeAdd(initialRecipientBalance, withdrawAmount));
        // assert: loan balance reduced
        assertEq(shelf.balances(loanId), safeSub(initialLoanBalance, withdrawAmount));
        // assert: total balance reduced
        assertEq(shelf.balance(), safeSub(initialTotalBalance, withdrawAmount));
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
        initBorrow(loanId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        // move funds into shelf
        distributor.balance();
        assertPreCondition(loanId, tokenId, loanAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testWithdrawToOtherUserAccount() public {
        uint loanAmount = 100 ether;
        uint investAmount = safeMul(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        assertPreCondition(loanId, tokenId, loanAmount);
        // recipient not borrower account
        withdraw(loanId, tokenId, loanAmount, randomUser_);
    }

    function testWithdrawFromShelfHasFunds() public {
        uint loanAmount = 100 ether;
        uint investAmount = safeMul(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, loanAmount, borrower_);
        // transfer funds directly into the shelf, without calling tranche.supply()
        supplyFunds(investAmount, address(shelf));
        assertPreCondition(loanId, tokenId, loanAmount);
        withdraw(loanId, tokenId, loanAmount, borrower_);
    }

    function testPartialWithdraw() public {
        uint loanAmount = 100 ether;
        // just withdraw half of your loan balance
        uint withdrawAmount = safeDiv(loanAmount, 2);
        uint investAmount = safeMul(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, loanAmount, borrower_);
        // junior investor puts money into tranche
        invest(investAmount);
        assertPreCondition(loanId, tokenId, withdrawAmount);
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
        initBorrow(loanId, loanAmount, borrower_);
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
        initBorrow(loanId, loanAmount, randomUser_);
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
        uint investAmount = safeDiv(loanAmount, 2);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // init borrow -> add loan balance
        initBorrow(loanId, loanAmount, borrower_);
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
        initBorrow(loanId, loanAmount, borrower_);
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

    function initBorrow(uint loanId, uint amount, address usr) public {
        uint ceiling = amount;
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        // init rate group
        admin.doInitRate(rate, speed);
        // add loan to rate group
        admin.doAddRate(loanId, rate);
        // borrower borrows -> loan[balance] = amount
        Borrower(usr).borrow(loanId, amount);
    }
}