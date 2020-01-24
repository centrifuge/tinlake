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

contract SupplyTest is SystemTest {

    WhitelistOperator operator;
    SwitchableDistributor switchable;

    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_, false);
        operator = WhitelistOperator(address(juniorOperator));
        switchable = SwitchableDistributor(address(distributor));
        createTestUsers();
    }

    function testSimpleSupply() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        currency.mint(juniorInvestor_, investorBalance);
        assertPreCondition();

        juniorInvestor.doSupply(supplyAmount);
        assertPostCondition(investorBalance, supplyAmount);
    }

    function assertPreCondition() public view {
        // assert: borrowFromTranches == true
        assert(switchable.borrowFromTranches());
    }

    function assertPostCondition(uint investorBalance, uint supplyAmount) public {
        // assert: junior investor currency balance is equal to the inital balance - how much was supplied
        assertEq(currency.balanceOf(juniorInvestor_), investorBalance - supplyAmount);
        // assert: junior investor token balance == amount supplied (because no other currency was supplied yet)
        assertEq(lenderDeployer.juniorERC20().balanceOf(juniorInvestor_), supplyAmount);
        //assert: balance supplied has been moved to shelf
        assertEq(currency.balanceOf(address(borrowerDeployer.shelf())), supplyAmount);
    }

    function testFailNoSupplyAllowed() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        switchable.file("borrowFromTranches", false);

        juniorInvestor.doSupply(supplyAmount);
        assertPostCondition(investorBalance, supplyAmount);
    }

    function testFailInvestorNotWhitelisted() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        operator.denyInvestor(juniorInvestor_);

        juniorInvestor.doSupply(supplyAmount);
        assertPostCondition(investorBalance, supplyAmount);
    }
}

