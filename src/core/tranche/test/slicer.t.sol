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
import "../../test/mock/reserve.sol";
import "../../test/mock/manager.sol";

contract Hevm {
    function warp(uint256) public;
}

contract SlicerTest is DSTest {

    Slicer slicer;
    Hevm hevm;
    ReserveMock reserve;
    ManagerMock manager;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        manager = new ManagerMock();
        reserve = new ReserveMock();
        slicer = new Slicer(address(manager), address(reserve));
    }

    function testGetSlice() public {
        uint currencyAmount = 50;
        reserve.setTokenSupplyReturn(400);
        manager.setAssetReturn(200);

        uint slice = slicer.getSlice(currencyAmount);

        // 200 (total assets) / 400 (total token supply) = 0.5 (price / token) => 50 * 0.5 = 100 
        assertEq(slice, 100);
    }

    function testGetPayout() public { 
        uint tokenAmount = 50; // 5 % per year
        reserve.setTokenSupplyReturn(400);
        manager.setAssetReturn(200);

        uint payout = slicer.getPayout(tokenAmount);

        // 200 (total assets) / 400 (total token supply) = 0.5 (price / token) => 50 / 0.5 = 25
        assertEq(payout, 25);
    }
}


