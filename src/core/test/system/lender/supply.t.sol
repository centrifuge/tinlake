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

import "../system.t.sol";

contract SupplyTest is SystemTest {

    function testSupply() public {
        supply(100 ether, 10 ether);
        assertEq(currency.balanceOf(juniorInvestor_), 90 ether);
        assertEq(lenderDeployer.juniorERC20().balanceOf(juniorInvestor_), 10 ether);
        assertEq(currency.balanceOf(address(borrowerDeployer.shelf())), 10 ether);
    }
}

