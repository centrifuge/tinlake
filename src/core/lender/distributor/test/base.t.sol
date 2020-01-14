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

pragma solidity >=0.4.23;

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

contract SeniorMock is TrancheMock  {
    // support different return based on called
    function debt() public returns (uint) {
        uint called = calls["debt"];
        if(called == 0) {
            return call("debt");
        }
        calls["debt"]++;
        return values_return["debt_2"];
    }
}

contract SingleTrancheTest is DSTest, Math {
    BaseDistributor distributor;

    TrancheMock junior;
    address junior_;
    TrancheMock senior;
    address senior_;
    address shelf_;
    ShelfMock shelf;

    Hevm hevm;
    
    bool requestWant = true;

    function setUp() public {
        junior = new TrancheMock(); junior_ = address(junior);
        shelf = new ShelfMock(); shelf_ = address(shelf);

        distributor = new BaseDistributor(shelf_);
        distributor = new BaseDistributor(shelf_);
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

contract TwoTranchesTest is DSTest, Math {
    BaseDistributor distributor;

    TrancheMock junior;
    address junior_;
    TrancheMock senior;
    address senior_;
    address shelf_;
    ShelfMock shelf;

    Hevm hevm;

    bool requestWant = true;

    function setUp() public {
        junior = new TrancheMock(); junior_ = address(junior);
        senior = new SeniorMock(); senior_ = address(senior);
        shelf = new ShelfMock(); shelf_ = address(shelf);
        distributor = new BaseDistributor(shelf_);

        distributor.depend("senior", senior_);
        distributor.depend("junior", junior_);

    }

    function balanceExpectBorrow(uint juniorAmount, uint seniorAmount) public {
        distributor.balance();

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), juniorAmount);
        assertEq(junior.values_address("borrow_usr"), shelf_);

        assertEq(senior.calls("borrow"), 1);
        assertEq(senior.values_uint("borrow_amount"), seniorAmount);
        assertEq(senior.values_address("borrow_usr"), shelf_);

    }

    // --- Tests ---
    function testSetupCheck() public {
        assertEq(address(distributor.senior()), senior_);
        assertEq(address(distributor.junior()), junior_);
        assertEq(address(distributor.shelf()), shelf_);
    }

    function testBorrowOnlyJunior() public {
        uint amount = 100 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        // doesn't matter
        senior.setReturn("balance", 200 ether);

        distributor.balance();

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), amount);
        assertEq(junior.values_address("borrow_usr"), shelf_);

        // no senior calls
        assertEq(senior.calls("borrow"), 0);
    }

    function testBorrowFromBoth() public {
        uint amount = 150 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        // doesn't matter
        senior.setReturn("balance", 200 ether);

        // borrow junior: 100, senior: 50
        balanceExpectBorrow(100 ether, 50 ether);

    }

    function testBorrowTakeAll() public {
        uint amount = 300 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        // doesn't matter
        senior.setReturn("balance", 200 ether);

        // borrow junior: 100, senior: 200
        balanceExpectBorrow(100 ether, 200 ether);
    }

    function testFailBorrowTooHigh() public {
        uint amount = 301 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        // doesn't matter
        senior.setReturn("balance", 200 ether);

        // borrow junior: 100, senior: 200
        balanceExpectBorrow(100 ether, 50 ether);
    }

    function testRepayOnlySenior() public {
        uint amount = 50 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", 100 ether);

        distributor.balance();

        assertEq(senior.calls("repay"), 1);
        assertEq(senior.values_uint("repay_amount"), amount);
        assertEq(senior.values_address("repay_usr"), shelf_);

        assertEq(junior.calls("repay"), 0);
    }

    function testRepayOnlyJunior() public {
        uint amount = 50 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", 0);

        distributor.balance();

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), amount);
        assertEq(junior.values_address("repay_usr"), shelf_);

        assertEq(senior.calls("repay"), 0);
    }

    function testRepayOnlyJuniorWithBalance() public {
        uint amount = 50 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", 0);
        junior.setReturn("balance", 100 ether);

        distributor.balance();

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), amount);
        assertEq(junior.values_address("repay_usr"), shelf_);

        assertEq(senior.calls("repay"), 0);
    }

    function testRepayBothTranches() public {
        uint amount = 150 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", 50 ether);

        distributor.balance();

        assertEq(senior.calls("repay"), 1);
        assertEq(senior.values_uint("repay_amount"), 50 ether);
        assertEq(senior.values_address("repay_usr"), shelf_);

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), 100 ether);
        assertEq(junior.values_address("repay_usr"), shelf_);
    }

    function testRepaySeniorCoveredByJuniorReserve() public {
        uint amount = 100 ether;
        uint debtSenior = 50 ether;
        uint balanceJunior = 50 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", debtSenior);
        // second debt call the debt is already repaid
        senior.setReturn("debt_2", 0 ether);
        junior.setReturn("balance", balanceJunior);

        // junior -> senior 50 ether
        // available -> junior 100 ether
        distributor.balance();

        assertEq(senior.calls("repay"), 1);
        assertEq(senior.values_uint("repay_amount"), 50 ether);
        assertEq(senior.values_address("repay_usr"), junior_);

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), 100 ether);
        assertEq(junior.values_address("repay_usr"), shelf_);

    }

    function testRepaySeniorWithJuniorAndAvailable() public {
        uint amount = 100 ether;
        uint juniorBalance = 10 ether;
        uint debtSenior = 50 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", debtSenior);
        // second debt call return should be 40 ether
        senior.setReturn("debt_2", debtSenior - juniorBalance);

        junior.setReturn("balance", juniorBalance);

        // debt from senior is repaid with junior reserve and available
        // junior -> senior 10 ether
        // available -> senior 40 ether (senior debt repaid)
        // available -> junior 60 ether (the rest)
        distributor.balance();

        assertEq(senior.calls("repay"), 2);

        // from second repay call
        //debtSenior - juniorBalance
        assertEq(senior.values_uint("repay_amount"), 40 ether);
        assertEq(senior.values_address("repay_usr"), shelf_);

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), 60 ether);
        assertEq(junior.values_address("repay_usr"), shelf_);
    }

}

