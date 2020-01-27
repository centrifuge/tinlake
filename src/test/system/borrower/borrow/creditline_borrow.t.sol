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

pragma solidity >=0.5.12;

import "../../base_system.sol";

contract CreditLineBorrowTest is BaseSystemTest {
    
    Hevm public hevm;

    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "default";
        bytes32 ceiling_ = "creditline";
        baseSetup(juniorOperator_, distributor_, false, ceiling_);
        createTestUsers(false);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
    }
    
    function borrow(uint loanId, uint tokenId, uint amount) public {
        uint initialTotalBalance = shelf.balance();
        uint initialLoanBalance = shelf.balances(loanId);
        uint initialTotalDebt = pile.total();
        uint initialLoanDebt = pile.debt(loanId);
        uint initialCeiling = ceiling.ceiling(loanId);

        borrower.borrow(loanId, amount);
        assertPostCondition(loanId, tokenId, amount, initialTotalBalance, initialLoanBalance, initialTotalDebt, initialLoanDebt, initialCeiling);
    }

    function assertPreCondition(uint loanId, uint tokenId, uint amount) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrowAmount <= ceiling
        assert(amount <= ceiling.ceiling(loanId));
    }

    function assertPostCondition(uint loanId, uint tokenId, uint amount, uint initialTotalBalance, uint initialLoanBalance, uint initialTotalDebt, uint initialLoanDebt, uint initialCeiling) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: borrower nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: totalBalance increase by borrow amount
        assertEq(shelf.balance(), safeAdd(initialTotalBalance, amount));
        // assert: loanBalance increase by borrow amount
        assertEq(shelf.balances(loanId), safeAdd(initialLoanBalance, amount));
        // assert: totalDebt increase by borrow amount
        assertEq(pile.total(), safeAdd(initialTotalDebt, amount));
        // assert: loanDebt increase by borrow amount
        assertEq(pile.debt(loanId), safeAdd(initialLoanDebt, amount));
        // assert: available borrow amount decreased
        assertEq(ceiling.ceiling(loanId), safeSub(initialCeiling, amount));
    }

    function testBorrow() public {
        uint ceiling = 100 ether;
        uint amount = ceiling;
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        // lock nft for borrower
        lockNFT(loanId, borrower_);
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        assertPreCondition(loanId, tokenId, amount);
        borrow(loanId, tokenId, amount);
    }

    function testPartialBorrow() public {
        uint ceiling = 200 ether;
        // borrow amount smaller then ceiling
        uint amount = safeDiv(ceiling , 2);
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        admin.setCeiling(loanId, ceiling);
        assertPreCondition(loanId, tokenId, amount);
        borrow(loanId, tokenId, amount);
    }

    function testFailBorrowAmountTooHigh() public {
        uint ceiling = 100 ether;
        // borrow amount higher then ceiling
        uint amount = safeMul(ceiling, 2);
        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        lockNFT(loanId, borrower_);
        admin.setCeiling(loanId, ceiling);
        borrow(loanId, tokenId, amount);
    }

    function testFailBorrowInterestAccrued() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        uint amount = safeDiv(ceiling, 2) ;

        (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
        // lock nft for borrower
        lockNFT(loanId, borrower_);
        // admin sets loan parameters
        setLoanParameters(loanId, ceiling, rate, speed);
        assertPreCondition(loanId, tokenId, amount);
        // borrow half of the money
        borrow(loanId, tokenId, amount);
    
        hevm.warp(now + 365 days); // expected debt after 1 year 36.96 ether

        // borrower borrows other half of initial ceiling (33 ether) 
        // -> should fail. Not enough ceiling left, because of accrued interest. 69.96 > 66 (creditline)
        borrow(loanId, tokenId, amount);
    }

}