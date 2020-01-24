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


contract SystemTest is TestSetup, Math, DSTest {
    // users
    Borrower borrower;
    address borrower_;

    AdminUser public admin;
    address admin_;

    Investor public juniorInvestor;
    address public juniorInvestor_;

    Borrower randomUser;
    address randomUser_;

    function baseSetup(bytes32 operator_, bytes32 distributor_, bool senior_) public {
        // setup deployment
        deployContracts(operator_, distributor_, senior_);
        rootAdmin.relyLenderAdmin(address(this), senior_);
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

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function setupCurrencyOnLender(uint amount) public {
        // mint currency
        currency.mint(address(this), amount);
        currency.approve(address(junior), amount);
        uint balanceBefore = juniorERC20.balanceOf(address(this));
        // move currency into junior tranche
        address operator_ = address(juniorOperator);
        WhitelistOperator(operator_).relyInvestor(address(this));
        WhitelistOperator(operator_).supply(amount);
        // same amount of junior tokens
        assertEq(juniorERC20.balanceOf(address(this)), balanceBefore + amount);
    }

    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(addr), amount);
    }
}