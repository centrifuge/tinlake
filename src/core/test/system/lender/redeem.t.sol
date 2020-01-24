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
import {SwitchableDistributor} from "../../../lender/distributor/switchable.sol";

contract RedeemTest is SystemTest {
    
    SwitchableDistributor switchable;
    
    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_);
        switchable = SwitchableDistributor(address(distributor));
        createTestUsers();
    }

    function supply(uint balance, uint amount) public {
        currency.mint(juniorInvestor_, balance);
        juniorInvestor.doSupply(amount);
    }

    function testSwitchableRedeem() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        supply(investorBalance, supplyAmount);
        switchable.file("borrowFromTranches", false);
        assertPreCondition();

        juniorInvestor.doRedeem(supplyAmount);
        assertPostCondition(investorBalance);
    }

    function assertPreCondition() public view {
        // assert: borrowFromTranches == false
        assert(!switchable.borrowFromTranches());
        // assert: shelf is not bankrupt
        assert(currency.balanceOf(address(borrowerDeployer.shelf())) > 0);
    }

    function assertPostCondition(uint investorBalance) public {
        // assert: no more tokens left for junior investor
        assertEq(lenderDeployer.juniorERC20().balanceOf(juniorInvestor_), 0);
        // assert: junior currency balance back to initial pre-supply amount
        assertEq(currency.balanceOf(juniorInvestor_), investorBalance);
    }

    function testFailNoRedeemingAllowed() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        supply(investorBalance, supplyAmount);
        juniorInvestor.doRedeem(supplyAmount);
        assertPostCondition(investorBalance);
    }

    function testFailShelfBankrupt() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        supply(investorBalance, supplyAmount);
        switchable.file("borrowFromTranches", false);
        juniorInvestor.doRedeem(supplyAmount);
        juniorInvestor.doRedeem(supplyAmount);
    }
}