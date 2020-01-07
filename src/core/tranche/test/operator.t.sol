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

import "../seniorOperator.sol";
import "../../test/mock/reserve.sol";
import "../../test/mock/slicer.sol";

contract Hevm {
    function warp(uint256) public;
}

contract OperatorTest is DSTest {
    SeniorOperator operator;
    ReserveMock reserve;
    SlicerMock slicer;
    Hevm hevm;

    function setUp() public {
        reserve = new ReserveMock();
        slicer = new SlicerMock();
        operator = new SeniorOperator(address(reserve), address(slicer));
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
    }


    function supply() internal {
        uint currencyAmount = 200 ether;
        uint tokenAmount = 100;

        slicer.setTokenBalanceReturn(tokenAmount);
        operator.supply(address(this), currencyAmount);

        assertEq(slicer.callsGetSlice(), 1);
        assertEq(reserve.callsSupply(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(reserve.tokenAmount(), tokenAmount);
    }

    function redeem(uint tokenAmount, uint usrSlice, uint redeemTokenAmount) internal {
        uint currencyAmount = 200 ether;

        reserve.setTokenBalanceReturn(usrSlice);
        slicer.setPayoutReturn(currencyAmount);

        operator.redeem(address(this), tokenAmount);
        assertEq(slicer.callsGetPayout(), 1);
        assertEq(reserve.callsRedeem(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(reserve.tokenAmount(), redeemTokenAmount);
    }

    function repay(uint currencyAmount) internal { 
        operator.repay(address(this), currencyAmount);
        assertEq(reserve.callsRepay(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(operator.debt(), 0);
    }

    function borrow(uint currencyAmount) internal {
        operator.borrow(address(this), currencyAmount);

        assertEq(reserve.callsBorrow(), 1);
        assertEq(reserve.usr(), address(this));
        assertEq(reserve.currencyAmount(), currencyAmount);
        assertEq(operator.debt(), currencyAmount);
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

    function testBorrow() public {
        borrow(200 ether);
    }

    function testBorrowAndRepay() public {
        uint borrowRate = uint(1000000003593629043335673583);
        operator.file( "borrowrate", borrowRate);
        borrow(66 ether);
        hevm.warp(now + 365 days);
        repay(73.92 ether);
    }

    function testFileBorrowRate() public {
        uint borrowRate = uint(1000000003593629043335673583);
        operator.file( "borrowrate", borrowRate);
        (, uint actual, ) = operator.borrowRate();
        assertEq(borrowRate, actual);
    }
  
    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
}
