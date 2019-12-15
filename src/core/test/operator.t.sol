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
import "./mock/reserve.sol";
import "./mock/slicer.sol";
import "./mock/quant.sol";

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
        uint wadT = 200 ether;
        uint wadS = 100;
        uint takeSpeed = ONE;
        uint debt = 0;

        slicer.setChopReturn(wadS);
        quant.setSpeedReturn(takeSpeed);
        quant.setDebtReturn(debt);
        reserve.setBalanceReturn(wadT);

        operator.supply(address(this), wadT);

        assertEq(slicer.callsChop(), 1);
        assertEq(reserve.callsSupply(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.wadT(), wadT);
        assertEq(reserve.wadS(), wadS);
        checkSlicerUpdated(takeSpeed, debt, wadT);
    }

    function redeem(uint wadS, uint usrSlice, uint redeemWadS) internal {
        uint wadT = 200 ether;
        uint takeSpeed = ONE;
        uint debt = 0;
        uint balance = 200;

        reserve.setSliceReturn(usrSlice);
        reserve.setBalanceReturn(balance);
        slicer.setPayoutReturn(wadT);
        quant.setSpeedReturn(takeSpeed);
        quant.setDebtReturn(debt);

        operator.redeem(address(this), wadS);
        assertEq(slicer.callsPayout(), 1);
        assertEq(reserve.callsRedeem(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.wadT(), wadT);
        assertEq(reserve.wadS(), redeemWadS);
        checkSlicerUpdated(takeSpeed, debt, balance);
    }

    function give() internal { 
        uint wadT = 200 ether; 
        uint takeSpeed = ONE;
        uint debt = 0;

        quant.setSpeedReturn(takeSpeed);
        quant.setDebtReturn(debt);
        reserve.setBalanceReturn(wadT);

        operator.give(address(this), wadT);

        assertEq(reserve.callsGive(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.wadT(), wadT);
        assertEq(quant.callsUpdateDebt(), 1);
        assertEq(quant.wad(), (-1 * int(wadT)));
        checkSlicerUpdated(takeSpeed, debt, wadT);
    }

    function take() internal {
        uint wadT = 200 ether; 
        uint takeSpeed = ONE;
        uint debt = 0;
        uint balance = 0;

        quant.setSpeedReturn(takeSpeed);
        quant.setDebtReturn(debt);
        reserve.setBalanceReturn(balance);

        operator.take(address(this), wadT);
        
        assertEq(reserve.callsTake(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.wadT(), wadT);
        assertEq(quant.callsUpdateDebt(), 1);
        assertEq(quant.wad(), int(wadT));
        checkSlicerUpdated(takeSpeed, debt, balance);
    }

    function checkSlicerUpdated(uint speed, uint debt, uint reserve) internal {
        assertEq(slicer.callsUpdateISupply(), 1);
        assertEq(slicer.takeSpeed(), speed);
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
        uint wadS = 100;
        uint usrSlice = 150;
        redeem(wadS, usrSlice, wadS);
    }

    function testRedeemMax() public {        
        uint wadS = 200;
        uint usrSlice = 150;
        redeem(wadS, usrSlice, usrSlice);
    }

    function testFailRedeemNotActive() public {
        operator.file("redeem", false);
        uint wadS = 100;
        uint usrSlice = 150;
        redeem(wadS, usrSlice, wadS);
    }

    function testGive() public {
        give();
    }

    function testTake() public {
        take();
    }
}
