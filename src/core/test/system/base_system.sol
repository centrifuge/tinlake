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

import "ds-test/test.sol";
import "./setup.sol";
import "./users/admin.sol";
import "./users/investor.sol";
import "./users/borrower.sol";
import "tinlake-math/math.sol";


contract BaseSystemTest is TestSetup, Math, DSTest {
    // users
    Borrower borrower;
    address borrower_;
   
    AdminUser public admin;
    address admin_;

    Investor public juniorInvestor;
    address public juniorInvestor_;

    Borrower randomUser;
    address randomUser_;

    function baseSetup(bytes32 operator, bytes32 distributor) public {
        // setup deployment
        deployContracts(operator, distributor);
        rootAdmin.relyLenderAdmin(address(this));
    }

    function createTestUsers() public {
            borrower = new Borrower(address(shelf), address(lenderDeployer.distributor()), currency_, address(pile));
            borrower_ = address(borrower);

           randomUser = new Borrower(address(shelf), address(distributor), currency_, address(pile));
           randomUser_ = address(randomUser);

            admin = new AdminUser(address(shelf), address(pile), address(ceiling), address(title), address(lenderDeployer.distributor()));
            admin_ = address(admin);
            rootAdmin.relyBorrowAdmin(admin_);

            juniorInvestor = new Investor(address(juniorOperator), currency_, address(juniorERC20));
            juniorInvestor_ = address(juniorInvestor);
            WhitelistOperator juniorOperator = WhitelistOperator(address(juniorOperator));
            juniorOperator.relyInvestor(juniorInvestor_);  
    }

    // helpers borrower
    function issueNFT(address usr) public returns (uint, bytes32) {
        uint tokenId = collateralNFT.issue(usr);
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        // user approves shelf too lock NFT
        return (tokenId, lookupId);
    }

    function issueNFTAndCreateLoan(address usr) public returns (uint, uint) {
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(usr);
        // issue loan for borrower
        uint loanId = Borrower(usr).issue(collateralNFT_, tokenId);
        return (tokenId, loanId);
    }

    function lockNFT(uint loanId, address usr) public {
        Borrower(usr).approveNFT(collateralNFT, address(shelf));
        Borrower(usr).lock(loanId);
    } 

    function transferNFT(address sender, address recipient, uint tokenId) public {
        Borrower(sender).approveNFT(collateralNFT, address(this));
        collateralNFT.transferFrom(sender, recipient, tokenId);
    }

    // helpers admin
    function setLoanParameters(uint loanId, uint ceiling, uint rate, uint speed) public {
        // admin sets loan ceiling
        admin.setCeiling(loanId, ceiling);
        // init rate group
        admin.doInitRate(rate, speed);
        // add loan to rate group
        admin.doAddRate(loanId, rate);
        // admin sets loan rate
    }

    function setupCurrencyOnLender(uint amount) public {
        // mint currency
        currency.mint(address(this), amount);
        currency.approve(address(lenderDeployer.junior()), amount);
        uint balanceBefore = lenderDeployer.juniorERC20().balanceOf(address(this));
        // move currency into junior tranche
        address operator_ = address(lenderDeployer.juniorOperator());
        WhitelistOperator(operator_).relyInvestor(address(this));
        WhitelistOperator(operator_).supply(amount);
        // same amount of junior tokens
        assertEq(lenderDeployer.juniorERC20().balanceOf(address(this)), balanceBefore + amount);
    }

    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(addr), amount);
    }

}