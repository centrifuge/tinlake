// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "../base_system.sol";

contract WithdrawTest is BaseSystemTest {

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
        baseSetup();
        createTestUsers();
    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        defaultInvest(defaultAmount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        emit log_named_uint("reserve", reserve.totalBalance());
    }


    function withdraw(uint loanId, uint tokenId, uint amount, address usr) public {
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint reserveBalance = currency.balanceOf(address(reserve));
        uint initialAvailable = safeAdd(shelfBalance, reserveBalance);
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
        uint reserveBalance = currency.balanceOf(address(reserve));
        assert(safeAdd(shelfBalance, reserveBalance) >= amount);
    }

    function assertPostCondition(uint loanId, uint tokenId, uint withdrawAmount, address recipient, uint initialAvailable, uint initialRecipientBalance, uint initialLoanBalance, uint initialTotalBalance) public {
        // assert: nft still locked, shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: available balance decreased
        uint shelfBalance = currency.balanceOf(address(shelf));
        uint reserveBalance = currency.balanceOf(address(reserve));
        assertEq(safeAdd(shelfBalance, reserveBalance), safeSub(initialAvailable, withdrawAmount));
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
