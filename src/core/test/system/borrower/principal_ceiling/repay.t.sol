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
        baseSetup();
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
        uint initialDebt = pile.debt(loanId);
        uint initialTotalDebt = pile.total();
        uint initialShelfBalance = currency.balanceOf(address(shelf));
        borrower.repay(loanId, amount);
        assertPostCondition(loanId, tokenId, amount, initialBorrowerBalance, initialDebt, initialTotalDebt, initialShelfBalance, expectedDebt);
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
        // borrower has enough funds 
        assert(currency.balanceOf(borrower_) >= repayAmount);
    }

    function assertPostCondition(uint loanId, uint tokenId, uint repaidAmount, uint initialBorrowerBalance, uint initialDebt, uint initialTotalDebt, uint initialShelfBalance, uint expectedDebt) public {
        // assert: borrower still loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf still nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrower funds decreased by the smaller of repaidAmount or totalLoanDebt
        if (repaidAmount > expectedDebt) {
            // make sure borrower did not pay more then hs debt
            repaidAmount = expectedDebt;   
        }
        assertEq(sub(initialBorrowerBalance, repaidAmount), currency.balanceOf(borrower_));
        // assert: shelf received funds
        assertEq(add(initialShelfBalance, repaidAmount), currency.balanceOf(address(shelf)));
        // loanDebt & totalDebt decreased
        assert(pile.total() > initialTotalDebt);
        assert(pile.debt(loanId) > initialDebt);
    }


    function testRepayFullDebt() public {
        uint borrowAmount = 66 ether;
        uint investAmount = mul(2, borrowAmount);
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
        // admin sets parameters fo rthe loan
        setLoanParameters(loanId, borrowAmount, rate, speed);
        // borrower borrows funds
        borrow(loanId, tokenId, borrowAmount, borrower_);
        hevm.warp(now + 365 days);
        // supply borrower with additional funds to pay for accrued interest
        supplyFunds(extraFunds, borrower_);
        
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));

        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
        repay(loanId, tokenId, repayAmount, expectedDebt);
        assertEq(pile.debt(loanId), 0);
    }

    function testRepayMaxLoanDebt() public {
        uint borrowAmount = 66 ether;
        uint investAmount = mul(2, borrowAmount);
        // 12 % per year compound in seconds
        uint rate = 1000000003593629043335673583;
        uint speed = rate;
        // expected debt after 1 year of compounding
        uint expectedDebt = 73.92 ether;
        // borrower tries to repay twice his debt amount
        uint repayAmount = mul (expectedDebt, 2);
        uint extraFunds = 100 ether;
        // investor invests into tranche
        invest(investAmount);
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(borrower_);
        // issue loan for borrower
        uint loanId = borrower.issue(collateralNFT_, tokenId);
        // lock nft
        lockNFT(loanId, borrower_);
        // admin sets parameters fo rthe loan
        setLoanParameters(loanId, borrowAmount, rate, speed);
        // borrower borrows funds
        borrow(loanId, tokenId, borrowAmount, borrower_);
        hevm.warp(now + 365 days);
        // supply borrower with additional funds to pay for accrued interest
        supplyFunds(extraFunds, borrower_);
        
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));

        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
        repay(loanId, tokenId, repayAmount, expectedDebt);
        assertEq(pile.debt(loanId), 0);
    }

    function testPartialRepay() public {

    }

    function testFailRepayNotLoanOwner() public {

    }

    function testFailRepayNotNFTOwner() public {

    }

    function testFailRepayNotEnoughFunds() public {

    }
    
    function testFailRepayLoanHasFunds() public {

    }

    function testFailRepayZeroDebt() public {

    }

    function testFailRepayCurrencyNotApproved() public {

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

    function borrow(uint loanId, uint tokenId, uint amount, address usr) public {
        // borrower borrows -> loan[balance] = amount
        Borrower(usr).borrow(loanId, amount);
        // move funds into shelf
        distributor.balance();
        Borrower(usr).withdraw(loanId, amount, borrower_);
    }

    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(addr), amount);
    }
}