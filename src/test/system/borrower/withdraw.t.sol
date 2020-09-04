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

contract WithdrawTest is BaseSystemTest {

    Hevm public hevm;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        baseSetup();
        createTestUsers();
    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        invest(defaultAmount);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();
        emit log_named_uint("reserve", reserve.totalBalance());
    }

    function withdraw(uint loanId, uint tokenId, uint amount, address usr) public {
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint distributorBalance = currency.balanceOf(address(reserve));
        uint initialAvailable = safeAdd(shelfBalance, distributorBalance);
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
        uint distributorBalance = currency.balanceOf(address(reserve));
        assert(safeAdd(shelfBalance, distributorBalance) >= amount);
    }

    function assertPostCondition(uint loanId, uint tokenId, uint withdrawAmount, address recipient, uint initialAvailable, uint initialRecipientBalance, uint initialLoanBalance, uint initialTotalBalance) public {
        // assert: nft still locked, shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: available balance decreased
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint distributorBalance = currency.balanceOf(address(reserve));
        assertEq(safeAdd(shelfBalance, distributorBalance), safeSub(initialAvailable, withdrawAmount));
        // assert: borrower balance increased
        assertEq(currency.balanceOf(recipient), safeAdd(initialRecipientBalance, withdrawAmount));
        // assert: loan balance reduced
        assertEq(shelf.balances(loanId), safeSub(initialLoanBalance, withdrawAmount));
        // assert: total balance reduced
        assertEq(shelf.balance(), safeSub(initialTotalBalance, withdrawAmount));
    }

    function testWithdraw() public {
        fundTranches();
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testWithdrawToOtherUserAccount() public {
        fundTranches();
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, ceiling);
        // recipient not borrower account
        withdraw(loanId, tokenId, ceiling, randomUser_);
    }

    function testWithdrawFromShelfHasFunds() public {
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // transfer funds directly into the shelf, without calling tranche.supply()
        uint investAmount = safeMul(ceiling, 2);
        supplyFunds(investAmount, address(shelf));
        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testPartialWithdraw() public {
        fundTranches();
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // withdraw amount half of your loan balance
        uint withdrawAmount = safeDiv(ceiling, 2);
        (uint loanId, uint tokenId) = createLoanAndBorrow(borrower_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, withdrawAmount);
        withdraw(loanId, tokenId, withdrawAmount, borrower_);
    }

    function testFailWithdrawNFTnotLocked() public {
        fundTranches();
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        priceNFT(tokenId, nftPrice);
        // do not lock nft
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawNotLoanOwner() public {
        fundTranches();
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        (uint loanId, uint tokenId) = createLoanAndBorrow(randomUser_, nftPrice, riskGroup);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailLoanHasNFTNotPriced() public {
        fundTranches();
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawNotEnoughFundsAvailable() public {
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        (uint loanId, uint tokenId) = createLoanAndBorrow(randomUser_, nftPrice, riskGroup);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawTwice() public {
        fundTranches();
        uint nftPrice = 100 ether; // -> ceiling 50 ether
        uint riskGroup = 1; // -> 12% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);

        (uint loanId, uint tokenId) = createLoanAndBorrow(randomUser_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }
}
