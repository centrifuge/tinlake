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

contract UnlockTest is BaseSystemTest {

    Hevm public hevm;

    function setUp() public {
        baseSetup();
        createTestUsers(false);

        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        fundTranches();

    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        invest(defaultAmount);
        hevm.warp(now + 1 days);
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
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        hevm.warp(now + 365 days);

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
        borrower.doApproveCurrency(address(shelf), uint(-1));

        hevm.warp(now + 365 days);
        // borrower does not repay
        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockCollected() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        // thresholdRatio => 80% -> 160 ether
        uint riskGroup = 1; // -> 12% per year
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        // threshold reached after 10 years
        hevm.warp(now + 3650 days);
        seize(loanId);
        unlockNFT(loanId, tokenId);
    }
}
