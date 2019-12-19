// Copyright (C) 2019 lucasvo

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

import "../operator.sol";
import "../../test/mock/reserve.sol";
import "../../test/mock/slicer.sol";
import "../../test/mock/quant.sol";

contract OperatorTest is DSTest {
    Operator operator;
    ReserveMock reserve;
    SlicerMock slicer;
    QuantMock quant;

    uint256 constant ONE = 10 ** 27;

    function setUp() public {
        reserve = new ReserveMock();
        quant = new QuantMock();
        slicer = new SlicerMock();
        operator = new Operator(address(reserve), address(quant), address(slicer));
    }


    function supply() internal {
        uint currencyAmount = 200 ether;
        uint tokenAmount = 100;
        uint borrowSpeed = ONE;
        uint debt = 0;

        slicer.setCalcSliceReturn(tokenAmount);
        quant.setSpeedReturn(borrowSpeed);
        quant.setDebtReturn(debt);
        reserve.setBalanceReturn(currencyAmount);

        operator.supply(address(this), currencyAmount);

        assertEq(slicer.callsCalcSlice(), 1);
        assertEq(reserve.callsSupply(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(reserve.tokenAmount(), tokenAmount);
        checkSlicerUpdated(borrowSpeed, debt, currencyAmount);
    }

    function redeem(uint tokenAmount, uint usrSlice, uint redeemTokenAmount) internal {
        uint currencyAmount = 200 ether;
        uint borrowSpeed = ONE;
        uint debt = 0;
        uint balance = 200;


        reserve.setSliceReturn(usrSlice);
        reserve.setBalanceReturn(balance);
        slicer.setCalcPayoutReturn(currencyAmount);
        quant.setSpeedReturn(borrowSpeed);
        quant.setDebtReturn(debt);

        operator.redeem(address(this), tokenAmount);
        assertEq(slicer.callsCalcPayout(), 1);
        assertEq(reserve.callsRedeem(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(reserve.tokenAmount(), redeemTokenAmount);
        checkSlicerUpdated(borrowSpeed, debt, balance);
    }

    function repay() internal { 
        uint currencyAmount = 200 ether; 
        uint borrowSpeed = ONE;
        uint debt = 0;

        quant.setSpeedReturn(borrowSpeed);
        quant.setDebtReturn(debt);
        reserve.setBalanceReturn(currencyAmount);

        operator.repay(address(this), currencyAmount);

        assertEq(reserve.callsRepay(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(quant.callsUpdateDebt(), 1);
        assertEq(quant.loanAmount(), (-1 * int(currencyAmount)));
        checkSlicerUpdated(borrowSpeed, debt, currencyAmount);
    }

    function borrow() internal {
        uint currencyAmount = 200 ether; 
        uint borrowSpeed = ONE;
        uint debt = 0;
        uint balance = 0;

        quant.setSpeedReturn(borrowSpeed);
        quant.setDebtReturn(debt);
        reserve.setBalanceReturn(balance);

        operator.borrow(address(this), currencyAmount);
        
        assertEq(reserve.callsBorrow(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(quant.callsUpdateDebt(), 1);
        assertEq(quant.loanAmount(), int(currencyAmount));
        checkSlicerUpdated(borrowSpeed, debt, balance);
    }

    function checkSlicerUpdated(uint speed, uint debt, uint reserve) internal {
        assertEq(slicer.callsupdateSupplyRate(), 1);
        assertEq(slicer.borrowSpeed(), speed);
        assertEq(slicer.debt(), debt);
        assertEq(slicer.reserve(), reserve);
    }

    function testDeactivateSupply() public {
        assert(operator.supplyActive());
        operator.file("supply", false);
        assert(!operator.supplyActive());
    }

    function testDeactivateRedeem() public {
        assert(operator.redeemActive());
        operator.file("redeem", false);
        assert(!operator.redeemActive());
    }

    function testSupply() public {
        supply();
    }

    function testFailSupplyNotActive() public {
        operator.file("supply", false);
        supply();
    }

    function testRedeem() public {
        uint tokenAmount = 100;
        uint usrSlice = 150;
        redeem(tokenAmount, usrSlice, tokenAmount);
    }

    function testRedeemMax() public {        
        uint tokenAmount = 200;
        uint usrSlice = 150;
        redeem(tokenAmount, usrSlice, usrSlice);
    }

    function testFailRedeemNotActive() public {
        operator.file("redeem", false);
        uint tokenAmount = 100;
        uint usrSlice = 150;
        redeem(tokenAmount, usrSlice, tokenAmount);
    }

    function testRepay() public {
        repay();
    }

    function testBorrow() public {
        borrow();
    }
}
