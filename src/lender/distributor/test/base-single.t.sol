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

pragma solidity >=0.5.3;

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "../../test/mock/tranche.sol";
import "../../../borrower/test/mock/shelf.sol";
import "../../../borrower/test/mock/token.sol";
import "../default.sol";


contract Hevm {
    function warp(uint256) public;
}

contract DefaultDistributorSingleTrancheTest is DSTest, Math {
    DefaultDistributor distributor;
    address distributor_;

    TrancheMock junior;
    TokenMock currency;
    address currency_;
    address junior_;
    address shelf_;
    ShelfMock shelf;

    Hevm hevm;
    
    bool requestWant = true;

    function setUp() public {
        junior = new TrancheMock(); junior_ = address(junior);
        shelf = new ShelfMock(); shelf_ = address(shelf);
        currency = new TokenMock(); currency_ = address(currency);

        distributor = new DefaultDistributor(currency_);
        distributor_ = address(distributor);
        distributor.depend("shelf", shelf_);
        distributor.depend("junior", junior_);
    }

    function checkShelfTransferFrom(address from, address to, uint amount) public {
        assertEq(currency.calls("transferFrom"), 1);
        assertEq(currency.values_address("transferFrom_from"), from);
        assertEq(currency.values_address("transferFrom_to"), to);
        assertEq(currency.values_uint("transferFrom_amount"), amount);
    }

    function balanceExpectBorrow(uint amount) public {
        distributor.balance();

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), amount);
        assertEq(junior.values_address("borrow_usr"), distributor_);

        checkShelfTransferFrom(distributor_, shelf_, amount);
    }

    function balanceExpectRepay(uint amount) public {
        distributor.balance();

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), amount);
        assertEq(junior.values_address("repay_usr"), distributor_);

        checkShelfTransferFrom(shelf_, distributor_, amount);
    }

    // --- Tests ---
    function testSetupCheck() public {
        assertEq(address(distributor.junior()), junior_);
        assertEq(address(distributor.senior()), address(0));
        assertEq(address(distributor.shelf()), shelf_);
    }

    function testBorrow() public {
        uint amount = 100 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);

        junior.setReturn("balance", 200 ether);
        balanceExpectBorrow(amount);
    }

    function testBorrowAll() public {
        uint amount = 100 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", amount);
        balanceExpectBorrow(amount);
    }

    function testFailBorrowTooMuch() public {
        uint amount = 200 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        balanceExpectBorrow(amount);
    }
    
    function testRepay() public {
        uint amount = 200 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);
        balanceExpectRepay(amount);
    }

}

