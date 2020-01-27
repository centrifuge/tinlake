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

pragma solidity >=0.5.3;

import "../base_system.sol";

contract WithdrawTest is BaseSystemTest {

    DefaultDistributor distributor;
        
    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "default";
        baseSetup(juniorOperator_, distributor_, false);
        createTestUsers(false);
        distributor = DefaultDistributor(address(lenderDeployer.distributor()));
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
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint juniorBalance = currency.balanceOf(address(junior));
        assertEq(safeAdd(shelfBalance, juniorBalance), safeSub(initialAvailable, withdrawAmount));
        // assert: borrower balance increased
        assertEq(currency.balanceOf(recipient), safeAdd(initialRecipientBalance, withdrawAmount));
        // assert: loan balance reduced
        assertEq(shelf.balances(loanId), safeSub(initialLoanBalance, withdrawAmount));
        // assert: total balance reduced
        assertEq(shelf.balance(), safeSub(initialTotalBalance, withdrawAmount));
    }

    function testWithdraw() public {
        fundTranches();
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, ceiling, 0);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testWithdrawToOtherUserAccount() public {
        fundTranches();
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, ceiling, 0);
        assertPreCondition(loanId, tokenId, ceiling);
        // recipient not borrower account
        withdraw(loanId, tokenId, ceiling, randomUser_);
    }

    function testWithdrawFromShelfHasFunds() public {
        uint ceiling = 100 ether;
        // transfer funds directly into the shelf, without calling tranche.supply()
        uint investAmount = safeMul(ceiling, 2);
        supplyFunds(investAmount, address(shelf));
        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, ceiling, 0);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testPartialWithdraw() public {
        fundTranches();
        uint ceiling = 100 ether;
        // withdraw amount half of your loan balance
        uint withdrawAmount = safeDiv(ceiling, 2);
        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, ceiling, 0);
        assertPreCondition(loanId, tokenId, withdrawAmount);
        withdraw(loanId, tokenId, withdrawAmount, borrower_);
    }

    function testFailWithdrawNFTnotLocked() public {
        fundTranches();
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        // do not lock nft
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawNotLoanOwner() public {
        fundTranches();
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = createLoanAndBorrow(randomUser_, ceiling, 0);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailLoanHasNoBalance() public {
        fundTranches();
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        // do not init Borrow & add loan balance 
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawNotEnoughFundsAvailable() public {
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = createLoanAndBorrow(randomUser_, ceiling, 0);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawTwice() public {
        fundTranches();
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = createLoanAndBorrow(randomUser_, ceiling, 0);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }
}
