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

import "../../base_system.sol";

contract SupplyTest is BaseSystemTest {

    WhitelistOperator operator;

    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "default";
        bool deploySeniorTranche = false;

        baseSetup(juniorOperator_, distributor_, deploySeniorTranche);
        createTestUsers(deploySeniorTranche);
    }

    function testSimpleSupply() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        currency.mint(juniorInvestor_, investorBalance);

        juniorInvestor.doSupply(supplyAmount);
        assertPostCondition(supplyAmount);
    }

    function assertPostCondition(uint supplyAmount) public {
        // assert: shelf is balanced, excess has either been transferred to tranches or needed money transferred from distributor -> shelf
        assertEq(safeSub(shelf.balance(), currency.balanceOf(address(shelf))), 0);
        // assert: junior investor token balance == amount supplied (because no other currency was supplied yet)
        assertEq(juniorToken.balanceOf(juniorInvestor_), supplyAmount);
    }

    function testFailInvestorNotWhitelisted() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        currency.mint(juniorInvestor_, investorBalance);
        operator.denyInvestor(juniorInvestor_);

        juniorInvestor.doSupply(supplyAmount);
        assertPostCondition(supplyAmount);
    }
}
