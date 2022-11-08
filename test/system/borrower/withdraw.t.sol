// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
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
        uint256 defaultAmount = 1000 ether;
        defaultInvest(defaultAmount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        emit log_named_uint("reserve", reserve.totalBalance());
    }

    function withdraw(uint256 loanId, uint256 tokenId, uint256 amount, address usr) public {
        uint256 shelfBalance = currency.balanceOf(address(shelf));
        uint256 reserveBalance = currency.balanceOf(address(reserve));
        uint256 initialAvailable = safeAdd(shelfBalance, reserveBalance);
        uint256 initialRecipientBalance = currency.balanceOf(usr);
        uint256 initialLoanBalance = shelf.balances(loanId);
        uint256 initialTotalBalance = shelf.balance();
        borrower.withdraw(loanId, amount, usr);
        assertPostCondition(
            loanId,
            tokenId,
            amount,
            usr,
            initialAvailable,
            initialRecipientBalance,
            initialLoanBalance,
            initialTotalBalance
        );
    }

    function assertPreCondition(uint256 loanId, uint256 tokenId, uint256 amount) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: loan has enough balance
        assert(shelf.balances(loanId) >= amount);
        // assert: enough funds available
        uint256 shelfBalance = currency.balanceOf(address(shelf));
        uint256 reserveBalance = currency.balanceOf(address(reserve));
        assert(safeAdd(shelfBalance, reserveBalance) >= amount);
    }

    function assertPostCondition(
        uint256 loanId,
        uint256 tokenId,
        uint256 withdrawAmount,
        address recipient,
        uint256 initialAvailable,
        uint256 initialRecipientBalance,
        uint256 initialLoanBalance,
        uint256 initialTotalBalance
    ) public {
        // assert: nft still locked, shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: available balance decreased
        uint256 shelfBalance = currency.balanceOf(address(shelf));
        uint256 reserveBalance = currency.balanceOf(address(reserve));
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
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        (uint256 loanId, uint256 tokenId) = createLoanAndBorrow(borrower_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testWithdrawToOtherUserAccount() public {
        fundTranches();
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);

        (uint256 loanId, uint256 tokenId) = createLoanAndBorrow(borrower_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, ceiling);
        // recipient not borrower account
        withdraw(loanId, tokenId, ceiling, randomUser_);
    }

    function testPartialWithdraw() public {
        fundTranches();
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);

        // withdraw amount half of your loan balance
        uint256 withdrawAmount = safeDiv(ceiling, 2);
        (uint256 loanId, uint256 tokenId) = createLoanAndBorrow(borrower_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, withdrawAmount);
        withdraw(loanId, tokenId, withdrawAmount, borrower_);
    }

    function testFailWithdrawNFTnotLocked() public {
        fundTranches();
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);

        (uint256 loanId, uint256 tokenId) = issueNFTAndCreateLoan(borrower_);
        priceNFT(tokenId, nftPrice);
        // do not lock nft
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawNotLoanOwner() public {
        fundTranches();
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);

        (uint256 loanId, uint256 tokenId) = createLoanAndBorrow(randomUser_, nftPrice, riskGroup);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailLoanHasNFTNotPriced() public {
        fundTranches();
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);

        (uint256 loanId, uint256 tokenId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawNotEnoughFundsAvailable() public {
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);

        (uint256 loanId, uint256 tokenId) = createLoanAndBorrow(randomUser_, nftPrice, riskGroup);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }

    function testFailWithdrawTwice() public {
        fundTranches();
        uint256 nftPrice = 100 ether; // -> ceiling 50 ether
        uint256 riskGroup = 1; // -> 12% per year
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);

        (uint256 loanId, uint256 tokenId) = createLoanAndBorrow(randomUser_, nftPrice, riskGroup);
        assertPreCondition(loanId, tokenId, ceiling);
        withdraw(loanId, tokenId, ceiling, borrower_);
        withdraw(loanId, tokenId, ceiling, borrower_);
    }
}
