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

pragma solidity >=0.5.15 <0.6.0;

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "../../test/simple/token.sol";
import "./../reserve.sol";
import "./mock/assessor.sol";
import "../../borrower/test/mock/shelf.sol";

contract ReserveTest is DSTest, Math {

    SimpleToken currency;
    Reserve reserve;
    ShelfMock shelf;
    AssessorMock assessor;

    address shelf_;
    address reserve_;
    address currency_;
    address assessor_;

    address self;

    uint256 constant ONE = 10**27;

    function setUp() public {
        currency = new SimpleToken("CUR", "Currency", "1", 0);
        shelf = new ShelfMock();
        assessor = new AssessorMock();

        reserve = new Reserve(address(currency));

        shelf_ = address(shelf);
        reserve_ = address(reserve);
        currency_ = address(currency);
        assessor_ = address(assessor);
        self = address(this);

        reserve.depend("shelf", shelf_);
        reserve.depend("assessor", assessor_);
    }

    function testReserveBalanceBorrowFullReserve() public {
        uint borrowAmount = 100 ether;
        bool requestWant = true;
        // fund reserve with exact borrowAmount
        currency.mint(reserve_, borrowAmount);
        // borrow action: shelf requests currency
        shelf.setReturn("balanceRequest", requestWant, borrowAmount);

        uint reserveBalance = currency.balanceOf(reserve_);
        uint shelfBalance = currency.balanceOf(shelf_);

          // set maxCurrencyAvailable allowance to exact borrowAmount
        reserve.updateMaxCurrency(borrowAmount);
        uint currencyAvailable = reserve.currencyAvailable();

        reserve.balance();

        // assert currency was transferred from reserve to shelf
        assertEq(currency.balanceOf(reserve_), safeSub(reserveBalance, borrowAmount));
        assertEq(currency.balanceOf(shelf_), safeAdd(shelfBalance, borrowAmount));
        assertEq(reserve.currencyAvailable(), safeSub(currencyAvailable, borrowAmount));
        assertEq(assessor.values_uint("borrowUpdate_currencyAmount"), borrowAmount);
    }

    function testReserveBalanceBorrowPartialReserve() public {
        uint borrowAmount = 100 ether;
        bool requestWant = true;
        // fund reserve with twice as much currency then borrowAmount
        currency.mint(reserve_, safeMul(borrowAmount, 2));
        // borrow action: shelf requests currency
        shelf.setReturn("balanceRequest", requestWant, borrowAmount);

        uint reserveBalance = currency.balanceOf(reserve_);
        uint shelfBalance = currency.balanceOf(shelf_);

        // set maxCurrencyAvailable allowance to twice as much as borrowAmount
        reserve.updateMaxCurrency( safeMul(borrowAmount, 2));
        uint currencyAvailable = reserve.currencyAvailable();

        reserve.balance();

        // assert currency was transferred from reserve to shelf
        assertEq(currency.balanceOf(reserve_), safeSub(reserveBalance, borrowAmount));
        assertEq(currency.balanceOf(shelf_), safeAdd(shelfBalance, borrowAmount));
        assertEq(reserve.currencyAvailable(), safeSub(currencyAvailable, borrowAmount));
        assertEq(assessor.values_uint("borrowUpdate_currencyAmount"), borrowAmount);
    }

    function testReserveBalanceRepay() public {
        uint repayAmount = 100 ether;
        bool requestWant = false;
        // fund shelf with enough currency
        currency.mint(shelf_, repayAmount);
        // borrow action: shelf requests currency
        shelf.setReturn("balanceRequest", requestWant, repayAmount);
        // shelf approve reserve to take currency
        shelf.doApprove(currency_, reserve_, repayAmount);
        uint reserveBalance = currency.balanceOf(reserve_);
        uint shelfBalance = currency.balanceOf(shelf_);
        uint currencyAvailable = reserve.currencyAvailable();
        reserve.balance();

        // assert currency was transferred from shelf to reserve
        assertEq(currency.balanceOf(reserve_), safeAdd(reserveBalance, repayAmount));
        assertEq(currency.balanceOf(shelf_), safeSub(shelfBalance, repayAmount));
        assertEq(reserve.currencyAvailable(), currencyAvailable);
        assertEq(assessor.values_uint("repaymentUpdate_currencyAmount"), repayAmount);
    }

    function testFailBalancePoolInactive() public {
        uint borrowAmount = 100 ether;
        bool requestWant = true;
        // fund reserve with enough currency
        currency.mint(reserve_, 200 ether);
        // borrow action: shelf requests currency
        shelf.setReturn("balanceRequest", requestWant, borrowAmount);
        // set max available currency
        reserve.updateMaxCurrency(200 ether);
        // deactivate pool
        reserve.updateMaxCurrency(0 ether);

        reserve.balance();
    }

    function testFailBalanceBorrowAmountTooHigh() public {
        uint borrowAmount = 100 ether;
        bool requestWant = true;
        // fund reserve with enough currency
        currency.mint(reserve_, borrowAmount);
        // borrow action: shelf requests too much currency
        shelf.setReturn("balanceRequest", requestWant, safeMul(borrowAmount, 2));
        // set max available currency
        reserve.updateMaxCurrency(borrowAmount);
        reserve.balance();
    }

    function testFailBalanceReserveUnderfunded() public {
        uint borrowAmount = 100 ether;
        bool requestWant = true;
        // fund reserve with amount smaller than borrowAmount
        currency.mint(reserve_, safeSub(borrowAmount,1));
        // borrow action: shelf requests too much currency
        shelf.setReturn("balanceRequest", requestWant, safeMul(borrowAmount, 2));
        // set max available currency to borrowAmount
        reserve.updateMaxCurrency(borrowAmount);
        reserve.balance();
    }

    function testFailBalanceShelfNotEnoughFunds() public {
        uint repayAmount = 100 ether;
        bool requestWant = false;
        // fund shelf with currency amount smaller then repay amount
        currency.mint(shelf_, safeSub(repayAmount, 1));
        // borrow action: shelf requests currency
        shelf.setReturn("balanceRequest", requestWant, repayAmount);
        // shelf approve reserve to take currency
        shelf.doApprove(currency_, reserve_, repayAmount);
        reserve.balance();
    }
}
