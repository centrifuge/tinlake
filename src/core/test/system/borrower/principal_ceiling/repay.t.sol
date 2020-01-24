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

import "../../base_system.sol";

contract RepayTest is BaseSystemTest {

    SwitchableDistributor distributor;

    Hevm public hevm;
        
    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_, false);
        createTestUsers();
        
        distributor = SwitchableDistributor(address(lenderDeployer.distributor()));

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        fundTranches();
    }

    function repay(uint loanId, uint tokenId, uint amount, uint expectedDebt) public {
        uint initialBorrowerBalance = currency.balanceOf(borrower_);
        uint initialShelfBalance = currency.balanceOf(address(shelf));
        borrower.repay(loanId, amount);
        assertPostCondition(loanId, tokenId, amount, initialBorrowerBalance, initialShelfBalance, expectedDebt);
    }

    function assertPreCondition(uint loanId, uint tokenId, uint repayAmount, uint expectedDebt) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: loan has no open balance 
        assertEq(shelf.balances(loanId), 0);
        // assert: loan has open debt
        assert(pile.debt(loanId) > 0);
        // assert: debt includes accrued interest
        assertEq(pile.debt(loanId), expectedDebt);
        // assert: borrower has enough funds 
        assert(currency.balanceOf(borrower_) >= repayAmount);
    }

    function assertPostCondition(uint loanId, uint tokenId, uint repaidAmount, uint initialBorrowerBalance, uint initialShelfBalance, uint expectedDebt) public {
        // assert: borrower still loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf still nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrower funds decreased by the smaller of repaidAmount or totalLoanDebt
        if (repaidAmount > expectedDebt) {
            // make sure borrower did not pay more then hs debt
            repaidAmount = expectedDebt;   
        }
        assertEq(safeSub(initialBorrowerBalance, repaidAmount), currency.balanceOf(borrower_));
        // assert: shelf received funds
        assertEq(safeAdd(initialShelfBalance, repaidAmount), currency.balanceOf(address(shelf)));
        // assert: debt amounts reduced by repayAmount
        assertEq(pile.debt(loanId), safeSub(expectedDebt, repaidAmount));
        assertEq(pile.total(), safeSub(expectedDebt, repaidAmount));
    }

    function borrowAndRepay(address usr, uint ceiling, uint rate, uint speed, uint expectedDebt, uint repayAmount) public {
        (uint loanId, uint tokenId) = createLoanAndWithdraw(usr, ceiling, rate, speed);
        // supply borrower with additional funds to pay for accrued interest
        topup(usr);
        // borrower allows shelf full control over borrower tokens
        Borrower(usr).doApproveCurrency(address(shelf), uint(-1));
        //repay after 1 year
        hevm.warp(now + 365 days);
        repay(loanId, tokenId, repayAmount, expectedDebt);   
    }
    
    function testRepayFullDebt() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;
        borrowAndRepay(borrower_, ceiling, rate, speed, expectedDebt, repayAmount);
    }

    function testRepayMaxLoanDebt() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        // borrower tries to repay twice his debt amount
        uint repayAmount = safeMul(expectedDebt, 2);
        borrowAndRepay(borrower_, ceiling, rate, speed, expectedDebt, repayAmount);
    }

    function testPartialRepay() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt =  73.92 ether;
        uint repayAmount = safeDiv(expectedDebt, 2);
        borrowAndRepay(borrower_, ceiling, rate, speed, expectedDebt, repayAmount);
    }

    function testRepayDebtNoRate() public {
        uint ceiling = 66 ether;
        // do not set rate - default rate group: 0
        uint expectedDebt = ceiling;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling);

        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        //repay after 1 year
        hevm.warp(now + 365 days);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayNotLoanOwner() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;

         // supply borrower with additional funds to pay for accrued interest
        topup(borrower_);
        borrowAndRepay(randomUser_, ceiling, rate, speed, expectedDebt, repayAmount);
    }

    /*
    function testFailRepayNFTNotLocked() public {
       //TODO: test with collected NFT - next PR
    }
    */

    function testFailRepayNotEnoughFunds() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        
        hevm.warp(now + 365 days);
     
        // do not supply borrower with additional funds to repay interest

        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }
    
    function testFailRepayLoanNotFullyWithdrawn() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = ceiling;
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets parameters for the loan
        setLoanParameters(loanId, ceiling, rate, speed);
        // borrower add loan balance of full ceiling
        borrower.borrow(loanId, ceiling);
        // borrower just withdraws half of ceiling -> loanBalance remains
        borrower.withdraw(loanId, safeSub(ceiling, 2), borrower_);
        hevm.warp(now + 365 days);

        // supply borrower with additional funds to pay for accrued interest
        topup(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayZeroDebt() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets parameters for the loan
        setLoanParameters(loanId, ceiling, rate, speed);

        // borrower does not borrow
        
        // supply borrower with additional funds to pay for accrued interest
        topup(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayCurrencyNotApproved() public {
        uint ceiling = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = ceiling;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        //repay after 1 year
        hevm.warp(now + 365 days);

         // supply borrower with additional funds to pay for accrued interest
        topup(borrower_);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }
}