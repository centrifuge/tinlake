// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../base_system.sol";

contract UnlockTest is BaseSystemTest {

    function setUp() public {
        baseSetup();
        createTestUsers();

        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
        fundTranches();

    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        defaultInvest(defaultAmount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        emit log_named_uint("reserve", reserve.totalBalance());
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
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        assertPreCondition(loanId, tokenId);
        unlockNFT(loanId, tokenId);
    }

    function testUnlockNFTAfterRepay() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 0; // -> 0% per year
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        (uint loanId, ) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        hevm.warp(block.timestamp + 365 days);

//        // repay after 1 year  (no accrued interest, since loan per default in 0 rate group)
        repayLoan(borrower_, loanId, ceiling);
//        assertPreCondition(loanId, tokenId);
//        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockNotLoanOwner() public {
        // nft isued and loan created by random user
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(randomUser_);
        lockNFT(loanId, randomUser_);

        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockOpenDebt() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);

        hevm.warp(block.timestamp + 365 days);
        // borrower does not repay
        unlockNFT(loanId, tokenId);
    }
}
