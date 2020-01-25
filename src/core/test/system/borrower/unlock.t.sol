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

import "../base_system.sol";

contract UnlockTest is BaseSystemTest {

    Hevm public hevm;

    function setUp() public {

        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "default";
        baseSetup(juniorOperator_, distributor_, false);
        createTestUsers(false);
        fundTranches();

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
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        assertPreCondition(loanId, tokenId);
        unlockNFT(loanId, tokenId);
    }

    function testUnlockNFTAfterRepay() public {
        uint ceiling = 100 ether;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling);
         
        hevm.warp(now + 365 days);

        // repay after 1 year  (no accrued interest, since loan per default in 0 rate group)
        repayLoan(borrower_, loanId, ceiling);
        assertPreCondition(loanId, tokenId);
        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockNotLoanOwner() public {
        // nft isued and loan created by random user
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(randomUser_);
        lockNFT(loanId, randomUser_);

        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockOpenDebt() public {
        uint ceiling = 100 ether;
        // borrower creates loan and borrows funds
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        
        hevm.warp(now + 365 days);
        // borrower does not repay 
        unlockNFT(loanId, tokenId);
    }

    function testFailUnlockCollected() public {
        uint ceiling = 66 ether;
        uint threshold = 70 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(randomUser_, ceiling, rate, speed);
        // debt after 1 year: 73.92 ether -> threshold reached
        hevm.warp(now + 365 days);
        setThresholdAndSeize(loanId, threshold);
        unlockNFT(loanId, tokenId);
    }
}