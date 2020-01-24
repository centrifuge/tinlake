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

pragma solidity >=0.5.12;

import "../../system.t.sol";

contract SupplyTwoTrancheTest is BaseSystemTest {

    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bool deploySeniorTranche = true;

        baseSetup(operator_, distributor_, deploySeniorTranche);
        createTestUsers(deploySeniorTranche);
    }

    function testSimpleSupply() public {
        uint investorBalance = 100 ether;
        currency.mint(juniorInvestor_, 100 ether);
        currency.mint(seniorInvestor_, 100 ether);

        uint supplyAmount = 10 ether;
        juniorInvestor.doSupply(supplyAmount);
        seniorInvestor.doSupply(supplyAmount);

        assertEq(senior)

    }

    function assertPreCondition() public view {
        // assert:
    }

    function assertPostCondition(uint investorBalance, uint supplyAmount) public {
        // assert: junior investor currency balance is equal to the inital balance - how much was supplied
        assertEq(currency.balanceOf(juniorInvestor_), investorBalance - supplyAmount);
        // assert: junior investor token balance == amount supplied (because no other currency was supplied yet)
        assertEq(juniorERC20.balanceOf(juniorInvestor_), supplyAmount);
        //assert: balance supplied has been moved to shelf
        assertEq(currency.balanceOf(address(shelf)), supplyAmount);
    }
}