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
import "../../../borrower/test/mock/token.sol";
import "../switchable.sol";


contract Hevm {
    function warp(uint256) public;
}

contract SwitchableSingleTrancheTest is DSTest, Math {
    SwitchableDistributor distributor;
    TrancheMock junior;
    address junior_;
    TrancheMock senior;
    address senior_;
    TokenMock currency;

    address shelf_ = address(0x1234);
    Hevm hevm;

    function setUp() public {
        junior = new TrancheMock(); junior_ = address(junior);
        senior = new TrancheMock(); senior_ = address(senior);
        currency = new TokenMock();

        distributor = new SwitchableDistributor(address(currency));
        distributor.depend("shelf", shelf_);
        distributor.depend("junior", junior_);
        distributor.depend("senior", address(0));
    }

    function testBorrowSingleTranche() public {
        uint amount = 200 ether;
        junior.setReturn("balance", amount);

        distributor.balance();

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), amount);
        assertEq(junior.values_address("borrow_usr"), shelf_);
    }

    function testRepaySingleTranche() public {
        uint amount = 200 ether;
        distributor.file("borrowFromTranches", false);
        currency.setBalanceOfReturn(amount);

        distributor.balance();

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), amount);
        assertEq(junior.values_address("repay_usr"), shelf_);
    }

    function testBorrowTwoTranches() public {
        distributor.depend("senior", senior_);
        junior.setReturn("balance", 50 ether);
        senior.setReturn("balance", 100 ether);

        distributor.balance();

        assertEq(senior.calls("borrow"), 1);
        assertEq(senior.values_uint("borrow_amount"), 100 ether);
        assertEq(senior.values_address("borrow_usr"), shelf_);

        assertEq(junior.calls("borrow"), 1);
        assertEq(junior.values_uint("borrow_amount"), 50 ether);
        assertEq(junior.values_address("borrow_usr"), shelf_);
    }


    function testRepayTwoTranches() public {
        distributor.depend("senior", senior_);
        distributor.file("borrowFromTranches", false);

        uint amount = 150 ether;
        currency.setBalanceOfReturn(amount);
        senior.setReturn("debt", 100 ether);

        distributor.balance();

        assertEq(senior.calls("repay"), 1);
        assertEq(senior.values_uint("repay_amount"), 100 ether);
        assertEq(senior.values_address("repay_usr"), shelf_);

        assertEq(junior.calls("repay"), 1);
        assertEq(junior.values_uint("repay_amount"), 50 ether);
        assertEq(junior.values_address("repay_usr"), shelf_);
    }

}

