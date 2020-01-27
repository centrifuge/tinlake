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

contract JuniorMock is TrancheMock {
    function balance() public returns (uint) {
        uint called = calls["balance"];
        if(called == 0) {
            return super.balance();
        }
        calls["balance"]++;
        return values_return["balance_2"];
    }
}

contract SeniorMock is JuniorMock  {
    function repay(address usr, uint amount) public {
        uint called = calls["repay"];
        if(called == 0) {
            super.repay(usr, amount);
            return;
        }
        calls["repay"]++;
        values_address["repay_usr_2"] = usr;
        values_uint["repay_amount_2"] = amount;
    }

    // support different return based on called
    function debt() public returns (uint) {
        uint called = calls["debt"];
        if(called == 0) {
            return super.debt();
        }
        calls["debt"]++;
        return values_return["debt_2"];
    }
}

contract DefaultDistributorTwoTranches is DSTest, Math {
    DefaultDistributor distributor;
    address distributor_;

    JuniorMock junior;
    address junior_;
    TrancheMock senior;
    address senior_;
    TokenMock currency;
    address currency_;
    ShelfMock shelf;
    address shelf_;

    Hevm hevm;

    bool requestWant = true;

    function setUp() public {
        junior = new JuniorMock(); junior_ = address(junior);
        senior = new SeniorMock(); senior_ = address(senior);
        shelf = new ShelfMock(); shelf_ = address(shelf);
        currency = new TokenMock(); currency_ = address(currency);
        distributor = new DefaultDistributor(currency_);
        distributor_ = address(distributor);
        distributor.depend("shelf", shelf_);

        distributor.depend("senior", senior_);
        distributor.depend("junior", junior_);

    }

    function checkShelfTransferFrom(address from, address to, uint amount) public {
        // shelf -> distributor
        assertEq(currency.calls("transferFrom"), 1);
        assertEq(currency.values_address("transferFrom_from"), from);
        assertEq(currency.values_address("transferFrom_to"), to);
        assertEq(currency.values_uint("transferFrom_amount"), amount);
    }

    function balanceExpectBorrow(uint juniorAmount, uint seniorAmount) public {
        distributor.balance();

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), juniorAmount);

        assertEq(senior.calls("borrow"), 1);
        assertEq(senior.values_uint("borrow_amount"), seniorAmount);

        checkShelfTransferFrom(distributor_, shelf_, juniorAmount+seniorAmount);

    }

    function doRepayScenario(uint amount, uint debtSeniorFirstCall, uint debtSeniorSecondCall, uint balanceJunior, uint expectedJuniorRepay, uint expectedSeniorRepay,
        uint expectedSecondSeniorRepay) public {
        shelf.setReturn("balanceRequest", !requestWant, amount);

        // senior debt call returns
        senior.setReturn("debt", debtSeniorFirstCall);
        senior.setReturn("debt_2", debtSeniorSecondCall);

        junior.setReturn("balance", balanceJunior);

        distributor.balance();

        checkShelfTransferFrom(shelf_, distributor_, amount);

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), expectedJuniorRepay);

        uint seniorRepayCalls = senior.calls("repay");
        assertEq(senior.values_uint("repay_amount"), expectedSeniorRepay);

        if (seniorRepayCalls == 2) {
            assertEq(senior.values_uint("repay_amount_2"), expectedSecondSeniorRepay);
        }

    }

    // --- Tests ---
    function testSetupCheck() public {
        assertEq(address(distributor.senior()), senior_);
        assertEq(address(distributor.junior()), junior_);
        assertEq(address(distributor.shelf()), shelf_);
    }

    function testBorrowZero() public {
        shelf.setReturn("balanceRequest", requestWant, 0);
        junior.setReturn("balance", 100 ether);

        distributor.balance();
        // no senior calls
        assertEq(senior.calls("borrow"), 0);
    }

    function testRepayZero() public {
        shelf.setReturn("balanceRequest", !requestWant, 0);
        senior.setReturn("debt", 100 ether);

        distributor.balance();
        // no senior calls
        assertEq(senior.calls("repay"), 0);
    }

    function testBorrowOnlyJunior() public {
        uint amount = 100 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        junior.setReturn("balance_2", 100 ether);
        // doesn't matter
        senior.setReturn("balance", 200 ether);

        distributor.balance();

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), amount);

        checkShelfTransferFrom(distributor_, shelf_, amount);

        // no senior calls
        assertEq(senior.calls("borrow"), 0);
    }

    function testBorrowFromBoth() public {
        uint amount = 150 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        junior.setReturn("balance_2", 100 ether);
        // doesn't matter
        senior.setReturn("balance", 200 ether);

        // borrow junior: 100, senior: 50
        balanceExpectBorrow(100 ether, 50 ether);

    }

    function testBorrowAndTrancheBalance() public {
        uint amount = 150 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        senior.setReturn("debt", 70 ether);
        junior.setReturn("balance", 80 ether);
        // after senior repayment
        junior.setReturn("balance_2", 10 ether);

        senior.setReturn("balance", 200 ether);

        // borrow senior: 140 ether, junior: 10 ether
        uint juniorAmountBorrowed = 10 ether;
        uint seniorAmountBorrowed = 140 ether;
        distributor.balance();
        assertEq(currency.calls("transferFrom"), 1);

        // once in _balanceTranches and again in _borrowTranches
        assertEq(junior.calls("borrow"), 2);
        assertEq(junior.values_uint("borrow_amount"), juniorAmountBorrowed);

        assertEq(senior.calls("borrow"), 1);
        assertEq(senior.values_uint("borrow_amount"), seniorAmountBorrowed);

        checkShelfTransferFrom(distributor_, shelf_, juniorAmountBorrowed+seniorAmountBorrowed);
        // tranche balance
        // junior -> senior 70 ether
        assertEq(senior.calls("repay"), 1);
        assertEq(senior.values_uint("repay_amount"), 70 ether);
    }

    function testBorrowTakeAll() public {
        uint amount = 300 ether;
        shelf.setReturn("balanceRequest", requestWant, amount);
        junior.setReturn("balance", 100 ether);
        junior.setReturn("balance_2", 100 ether);
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
        senior.setReturn("debt_2", 100 ether);

        distributor.balance();

        assertEq(senior.calls("repay"), 1);
        assertEq(senior.values_uint("repay_amount"), amount);
        assertEq(junior.calls("repay"), 0);

        checkShelfTransferFrom(shelf_, distributor_, amount);
    }

    function testRepayOnlyJuniorScenarioA() public {
        // testRepayOnlyJunior - Scenario A: junior doesn't have a balance
        // no senior debt
        uint amount = 50 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);
        senior.setReturn("debt", 0);

        distributor.balance();

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), amount);
        checkShelfTransferFrom(shelf_, distributor_, amount);

        assertEq(senior.calls("repay"), 0);
    }

    function testRepayOnlyJuniorScenarioB() public {
        // testRepayOnlyJunior - Scenario B: junior has a balance
        // no senior debt
        uint amount = 50 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", 0);
        senior.setReturn("debt_2", 0 ether);
        junior.setReturn("balance", 100 ether);

        distributor.balance();

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), amount);

        checkShelfTransferFrom(shelf_, distributor_, amount);

        assertEq(senior.calls("repay"), 0);
    }

    function testRepayBothTranches() public {
        uint amount = 150 ether;
        shelf.setReturn("balanceRequest", !requestWant, amount);

        senior.setReturn("debt", 50 ether);
        senior.setReturn("debt_2", 50 ether);

        distributor.balance();

        assertEq(senior.calls("repay"), 1);
        assertEq(senior.values_uint("repay_amount"), 50 ether);

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), 100 ether);

        checkShelfTransferFrom(shelf_, distributor_, amount);
    }

    function testRepayScenarioA() public {
        // Repay Scenario A: debt of senior is covered by complete balance of junior

        uint amount = 100 ether;
        uint debtSeniorFirstCall = 50 ether;
        uint balanceJunior = 50 ether;

        // junior -> senior 50 ether
        // available -> junior 100 ether
        uint expectedJuniorRepay = 100 ether;
        // received from the first transfer
        uint expectedSeniorRepay = 50 ether;

        // only one senior repay call
        doRepayScenario(amount, debtSeniorFirstCall, 0, balanceJunior, expectedJuniorRepay,
            expectedSeniorRepay, 0);
    }

    function testRepayScenarioB() public {
        // Repay Scenario B: debt of senior is covered by balance of junior.
        // junior has more reserve than needed
        uint amount = 100 ether;
        uint balanceJunior = 100 ether;
        uint debtSeniorFirstCall = 50 ether;

        // debt from senior is repaid with junior reserve and available
        // junior -> senior 50 ether  (senior fully repaid)
        // available -> junior 100 ether (all)
        uint expectedJuniorRepay = 100 ether;
        // received from the first transfer
        uint expectedSeniorRepay = 50 ether;

        // only one senior repay call
        doRepayScenario(amount, debtSeniorFirstCall, 0, balanceJunior, expectedJuniorRepay,
            expectedSeniorRepay, 0);
    }

    function testRepayScenarioC() public {
        // Repay Scenario C: debt of senior is covered by balance of junior and available amount from borrower
        uint amount = 100 ether;
        uint balanceJunior = 10 ether;
        uint debtSeniorFirstCall = 50 ether;
        uint debtSeniorSecondCall = 40 ether;

        // debt from senior is repaid with junior reserve and available
        // junior -> senior 10 ether (complete junior balance)
        // available -> senior 40 ether (senior debt repaid)
        // available -> junior 60 ether (the rest)
        uint expectedSeniorRepay = 10 ether;
        uint expectedJuniorRepay = 60 ether;
        uint expectedSecondSeniorRepay = 40 ether;

        // two senior repay calls
        doRepayScenario(amount, debtSeniorFirstCall, debtSeniorSecondCall, balanceJunior, expectedJuniorRepay,
            expectedSeniorRepay, expectedSecondSeniorRepay);
    }

    function testRepayScenarioD() public {
        // Repay Scenario D: high senior debt partial repaid by junior and available
        // no payment to junior
        uint amount = 100 ether;
        uint balanceJunior = 10 ether;
        uint debtSeniorFirstCall = 50 ether;
        uint debtSeniorSecondCall = 200 ether;

        // debt from senior is repaid with junior reserve and available
        // junior -> senior 10 ether (complete junior balance)
        // available -> senior 40 ether (senior debt repaid)
        // available -> junior 60 ether (the rest)
        uint expectedSeniorRepay = 10 ether;
        uint expectedSecondSeniorRepay = 100 ether;

        shelf.setReturn("balanceRequest", !requestWant, amount);

        // senior debt call returns
        senior.setReturn("debt", debtSeniorFirstCall);
        senior.setReturn("debt_2", debtSeniorSecondCall);

        junior.setReturn("balance", balanceJunior);

        distributor.balance();

        // no junior repayment
        assertEq(junior.calls("repay"), 0);

        uint seniorRepayCalls = senior.calls("repay");
        assertEq(seniorRepayCalls, 2);
        assertEq(senior.values_uint("repay_amount"), expectedSeniorRepay);

        assertEq(senior.values_uint("repay_amount_2"), expectedSecondSeniorRepay);
    }

}

