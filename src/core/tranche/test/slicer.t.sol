// Copyright (C) 2019 

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

import "../slicer.sol";

contract Hevm {
    function warp(uint256) public;
}

contract SlicerTest is DSTest {

    Slicer slicer;
    Hevm hevm;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        slicer = new Slicer();
    }

    function testFileISupply() public {
        uint speed = uint(1000000003593629043335673583);
        slicer.file("isupply", speed);
        (, uint speedNow, ) = slicer.iSupply();
        assertEq(speed, speedNow);
    }

    function testFailFileISupplyWrongSelector() public {
        uint speed = uint(1000000003593629043335673583);
        slicer.file("iBorrow", speed);
        (, uint speedNow, ) = slicer.iSupply();
        assertEq(speed, speedNow);
    }

    function testDrip() public {
        uint speed = uint(1000000003593629043335673583);  // 12 % per year
        slicer.file("isupply", speed);
        uint initialDebt = 66 ether;
        hevm.warp(now + 365 days); // 1 year passed
        slicer.drip();

        (uint chiNow,,) = slicer.iSupply();
        uint debt = rmul(initialDebt, chiNow);
        // debt after one year: 66 ether * 1,12 = 73.92 
        assertEq(debt, 73.92 ether);
    }

    function testInstantCalcSlice() public {
        uint speed = uint(1000000001547125957863212450); // 5 % per year
        slicer.file("isupply", speed);
        uint currencyAmount = 100 ether;
        uint slice = slicer.calcSlice(currencyAmount);

        assertEq(slice, currencyAmount);
    }

    function testCalcSliceAfter1Year() public {
        uint speed = uint(1000000001547125957863212450); // 5 % per year
        slicer.file("isupply", speed);

        hevm.warp(now + 365 days); // 1 year passed
    
        uint currencyAmount = 100 ether;
        uint slice = slicer.calcSlice(currencyAmount);

        //100 / (1000000001547125957863212450) ^ (3600 * 24 * 365) 
        assertEq(slice, 95238095238095238093);
    }

    function testPayoutAfter1Year() public { 
        uint speed = uint(1000000003593629043335673583);  // 12 % per year
        slicer.file("isupply", speed);
        uint currencyAmount = 66 ether;
        uint slice = slicer.calcSlice(currencyAmount);
        uint payout = slicer.calcPayout(slice);

        assertEq(payout, 66 ether);
    }
 
    function testInstantPayout() public { 
        uint speed = uint(1000000003593629043335673583);  // 12 % per year
        slicer.file("isupply", speed);
        uint currencyAmount = 66 ether;
        uint slice = slicer.calcSlice(currencyAmount);

        hevm.warp(now + 365 days); // 1 year passed

        uint payout = slicer.calcPayout(slice);
        // 66 * (1000000003593629043335673583) ^ (3600 * 24 * 365) 
        assertEq(payout, 73.92 ether);
    }

    function testupdateSupplyRate() public {
        uint debt = 100 ether;
        uint reserve = 300 ether;
        uint borrowSpeed = uint(1000000001547125957863212450); // 5 % per year
                    
        slicer.updateSupplyRate(borrowSpeed, debt, reserve); 
        // 0.05 * (100  / (100 + 300)) ->  0.0125 
    
        (, uint speedNow, ) = slicer.iSupply();
        assertEq(speedNow, uint(1000000000386781489465803112));   
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


