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

contract RedeemTest is BaseSystemTest {

    WhitelistOperator operator;

    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "default";
        bool deploySeniorTranche = false;

        baseSetup(juniorOperator_, distributor_, deploySeniorTranche);
        createTestUsers(deploySeniorTranche);
    }

    function supply(uint balance, uint amount) public {
        currency.mint(juniorInvestor_, balance);
        juniorInvestor.doSupply(amount);
    }

    function testSimpleRedeem() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        uint redeemAmount = supplyAmount;
        supply(investorBalance, supplyAmount);

        juniorInvestor.doRedeem(redeemAmount);
        assertPostCondition(investorBalance);
    }

    function testPartialRedeem() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        uint redeemAmount = 5 ether;
        supply(investorBalance, supplyAmount);
        // first redeem
        juniorInvestor.doRedeem(redeemAmount);
        // second redeem
        juniorInvestor.doRedeem(redeemAmount);
        assertPostCondition(investorBalance);
    }

    function assertPostCondition(uint investorBalance) public {
        // assert: no more tokens left for junior investor
        assertEq(juniorToken.balanceOf(juniorInvestor_), 0);
        // assert: back to original balance
        assertEq(currency.balanceOf(juniorInvestor_), investorBalance);
        // assert: shelf is balanced, excess has either been transferred to tranches or needed money transferred from distributor -> shelf
        assertEq(safeSub(shelf.balance(), currency.balanceOf(address(shelf))), 0);
    }

    function testFailInvestorNotWhitelisted() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        supply(investorBalance, supplyAmount);
        operator.denyInvestor(juniorInvestor_);

        juniorInvestor.doRedeem(supplyAmount);
    }

    function testFailNotEnoughToken() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        uint redeemAmount = 15 ether;
        supply(investorBalance, supplyAmount);
        juniorInvestor.doRedeem(redeemAmount);
        assertPostCondition(investorBalance);
    }
}
