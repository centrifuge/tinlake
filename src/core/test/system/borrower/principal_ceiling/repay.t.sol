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
import "../../users/borrower.sol";
import "../../users/admin.sol";
import "../../users/investor.sol";

contract RepayTest is SystemTest {

    Borrower borrower;
    address borrower_;
   
    AdminUser public admin;
    address admin_;

    Investor public juniorInvestor;
    address public juniorInvestor_;

    Borrower randomUser;
    address randomUser_;

    SwitchableDistributor distributor;

    Hevm public hevm;
        
    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_);
        distributor = SwitchableDistributor(address(lenderDeployer.distributor()));

        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        // setup users
        borrower = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        borrower_ = address(borrower);

        randomUser = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        randomUser_ = address(randomUser);

        admin = new AdminUser(address(shelf), address(pile), address(ceiling), address(title), address(distributor));
        admin_ = address(admin);
        rootAdmin.relyBorrowAdmin(admin_);

        juniorInvestor = new Investor(address(juniorOperator), currency_, address(juniorERC20));
        juniorInvestor_ = address(juniorInvestor);
        WhitelistOperator juniorOperator = WhitelistOperator(address(juniorOperator));
        juniorOperator.relyInvestor(juniorInvestor_);
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

    function borrowAndRepay(address usr, uint borrowAmount, uint rate, uint speed, uint expectedDebt, uint repayAmount) public {
        uint extraFunds = 100 ether;
        uint investAmount = safeMul(2, borrowAmount);

        // supply borrower with additional funds to pay for accrued interest
        supplyFunds(extraFunds, usr);
        // borrower allows shelf full control over borrower tokens
        Borrower(usr).doApproveCurrency(address(shelf), uint(-1));
        // investor invests into tranche
        invest(investAmount);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(usr);
        // issue loan for borrower
        uint loanId = Borrower(usr).issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, usr);
        // admin sets parameters for the loan
        setLoanParameters(loanId, borrowAmount, rate, speed);
        // borrower borrows funds
        borrow(loanId, borrowAmount, usr);
        //repay after 1 year
        hevm.warp(now + 365 days);
        repay(loanId, tokenId, repayAmount, expectedDebt);
        
    }
    
    function testRepayFullDebt() public {
        uint borrowAmount = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;
        borrowAndRepay(borrower_, borrowAmount, rate, speed, expectedDebt, repayAmount);
    }

    function testRepayMaxLoanDebt() public {
        uint borrowAmount = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        // borrower tries to repay twice his debt amount
        uint repayAmount = safeMul(expectedDebt, 2);
        borrowAndRepay(borrower_, borrowAmount, rate, speed, expectedDebt, repayAmount);
    }

    function testPartialRepay() public {
        uint borrowAmount = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt =  73.92 ether;
        uint repayAmount = safeDiv(expectedDebt, 2);
        borrowAndRepay(borrower_, borrowAmount, rate, speed, expectedDebt, repayAmount);
    }

    function testRepayDebtNoRate() public {
        uint borrowAmount = 66 ether;
        // do not set rate - default rate group: 0
        uint expectedDebt = borrowAmount;
        uint ceiling = borrowAmount;
        uint repayAmount = expectedDebt;
       
        uint investAmount = safeMul(2, borrowAmount);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        // investor invests into tranche
        invest(investAmount);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = Borrower(borrower_).issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        // borrower borrows funds
        borrow(loanId, borrowAmount, borrower_);
        //repay after 1 year
        hevm.warp(now + 365 days);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayNotLoanOwner() public {
        uint borrowAmount = 66 ether;
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;
        uint extraFunds = 100 ether;

        // supplyFunds to borrower
        supplyFunds(extraFunds, borrower_);
        borrowAndRepay(randomUser_, borrowAmount, rate, speed, expectedDebt, repayAmount);
    }

    /*
    function testFailRepayNFTNotLocked() public {
       //TODO: test with collected NFT - next PR
    }
    */

    function testFailRepayNotEnoughFunds() public {
        uint borrowAmount = 66 ether;
        uint investAmount = safeMul(2, borrowAmount);
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;
        // investor invests into tranche
        invest(investAmount);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets parameters for the loan
        setLoanParameters(loanId, borrowAmount, rate, speed);
        // borrower borrows funds
        borrow(loanId, borrowAmount, borrower_);
        hevm.warp(now + 365 days);
     
        // do not supply borrower with additional funds to repay interest
        
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }
    
    function testFailRepayLoanNotWithdrawn() public {
        uint borrowAmount = 66 ether;
        uint investAmount = safeMul(2, borrowAmount);
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = borrowAmount;
        uint extraFunds = 100 ether;
        // investor invests into tranche
        invest(investAmount);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets parameters for the loan
        setLoanParameters(loanId, borrowAmount, rate, speed);
        // borrower add loan balance of full borrowAmount
        borrower.borrow(loanId, borrowAmount);
        // borrower just withdraws half of borrowAmount -> loanBalance remains
        borrower.withdraw(loanId, safeSub(borrowAmount, 2), borrower_);
        hevm.warp(now + 365 days);
        // supply borrower with additional funds to pay for accrued interest
        supplyFunds(extraFunds, borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayZeroDebt() public {
        uint borrowAmount = 66 ether;
        uint investAmount = safeMul(2, borrowAmount);
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = expectedDebt;
        uint extraFunds = 100 ether;
        // investor invests into tranche
        invest(investAmount);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets parameters for the loan
        setLoanParameters(loanId, borrowAmount, rate, speed);
        // borrower does not borrow
        
        supplyFunds(extraFunds, borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayCurrencyNotApproved() public {
        uint borrowAmount = 66 ether;
        uint investAmount = safeMul(2, borrowAmount);
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        uint repayAmount = borrowAmount;
        uint extraFunds = 100 ether;
        // supply borrower with additional funds to pay for accrued interest
        supplyFunds(extraFunds, borrower_);
  
        // borrower does not approve currency 

        // investor invests into tranche
        invest(investAmount);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets parameters for the loan
        setLoanParameters(loanId, borrowAmount, rate, speed);
        // borrower borrows funds
        borrow(loanId, borrowAmount, borrower_);
        //repay after 1 year
        hevm.warp(now + 365 days);
        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }
 
    // helpers
    function setLoanParameters(uint loanId, uint amount, uint rate, uint speed) public {
        uint ceiling = amount;
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        // init rate group
        admin.doInitRate(rate, speed);
        // add loan to rate group
        admin.doAddRate(loanId, rate);
        // admin sets loan rate
    }

    function lockNFT(uint loanId, address usr) public {
        Borrower(usr).approveNFT(collateralNFT, address(shelf));
        Borrower(usr).lock(loanId);
    } 

    function invest(uint amount) public {
        currency.mint(juniorInvestor_, amount);
        juniorInvestor.doSupply(amount);
    }

    function borrow(uint loanId, uint amount, address usr) public {
        // borrower borrows -> loan[balance] = amount
        Borrower(usr).borrow(loanId, amount);
        Borrower(usr).withdraw(loanId, amount, borrower_);
    }

    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(addr), amount);
    }
}