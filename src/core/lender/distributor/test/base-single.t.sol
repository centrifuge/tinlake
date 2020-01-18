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
import "tinlake-math/math.sol";

import "../../test/mock/tranche.sol";
import "../base.sol";


contract Hevm {
    function warp(uint256) public;
}

// todo replace it with borrower mock of Shelf
contract ShelfMock {
    uint calls;
    bool returnRequestWant;
    uint returnAmount;

    function balanceRequest() public returns (bool, uint) {
     return (returnRequestWant, returnAmount);
    }

    function setReturn(bytes32 name, bool requestWant, uint amount) public {
        returnRequestWant = requestWant;
        returnAmount = amount;
    }
}

contract BastDistributorSingleTrancheTest is DSTest, Math {
    BaseDistributor distributor;

    TrancheMock junior;
    address junior_;
    address shelf_;
    ShelfMock shelf;

    Hevm hevm;
    
    bool requestWant = true;

    function setUp() public {
        junior = new TrancheMock(); junior_ = address(junior);
        shelf = new ShelfMock(); shelf_ = address(shelf);

        distributor = new BaseDistributor();
        distributor.depend("shelf", shelf_);
        distributor.depend("junior", junior_);
    }

    function balanceExpectBorrow(uint amount) public {
        distributor.balance();

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), amount);
        assertEq(junior.values_address("borrow_usr"), shelf_);
    }

    function balanceExpectRepay(uint amount) public {
        distributor.balance();

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), amount);
        assertEq(junior.values_address("repay_usr"), shelf_);
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

