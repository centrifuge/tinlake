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

import "../../system.sol";

contract BalanceTest is SystemTest {
        
    SwitchableDistributor distributor;
    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "switchable";
        baseSetup(juniorOperator_, distributor_);
        createTestUsers();
        distributor = SwitchableDistributor(address(lenderDeployer.distributor()));
    }
    
    function balanceTake() public {
        uint initialShelfBalance = currency.balanceOf(address(shelf));
        uint takeAmount = currency.balanceOf(address(junior));
        borrower.balance();
        assertPostConditionTake(takeAmount, initialShelfBalance);
    }

    function balanceGive() public {
        uint initialJuniorBalance = currency.balanceOf(address(junior));
        uint giveAmount = currency.balanceOf(address(shelf));

        borrower.balance();
        assertPostConditionGive(giveAmount, initialJuniorBalance);
    }

    function assertPreConditionTake(uint takeAmount) public view {
        // assert: borrowFromTranches is active
        assert(distributor.borrowFromTranches());
        // assert: tranche reserve has enough funds
        assert(currency.balanceOf(address(junior)) == takeAmount);
    }

    function assertPostConditionTake(uint takeAmount, uint initialShelfBalance) public {
        // assert: takeAmount > 0
        assert(takeAmount > 0);
        // assert: all funds transferred from tranche reserve
        assertEq(currency.balanceOf(address(junior)), 0);
        // assert: shelf received funds
        assertEq(currency.balanceOf(address(shelf)), safeAdd(initialShelfBalance, takeAmount));
        // assert: distributor does not hold any funds
        assertEq(currency.balanceOf(address(distributor)), 0);
    }

    function assertPreConditionGive(uint giveAmount) public view {
        // assert: borrowFromTranches is inactive
        assert(!distributor.borrowFromTranches());
        // assert: shelf has funds
        assert(currency.balanceOf(address(shelf)) == giveAmount);
    }

    function assertPostConditionGive(uint giveAmount, uint initialJuniorBalance) public {
        // assert: giveAmount > 0
        assert(giveAmount > 0);
        // assert: all funds transferred from shelf
        assertEq(currency.balanceOf(address(shelf)), 0);
        // assert: junior received funds
        assertEq(currency.balanceOf(address(junior)), safeAdd(initialJuniorBalance, giveAmount));
        // assert: distributor does not hold any funds
        assertEq(currency.balanceOf(address(distributor)), 0);
    }

    function testBalanceTake() public {
        uint takeAmount = 100 ether;
        // supply junior tranche with funds
        supplyFunds(takeAmount, address(junior));
        assertPreConditionTake(takeAmount);
        // take money from tranche and transfer into shelf
        balanceTake();
    }

    function testFailBalanceTakeNoFundsAvailable() public {
        // junior tranche not supplied with capital
        balanceTake();
    }

    function testFailBalanceTakeInactive() public {
        uint takeAmount = 100 ether;
        // supply junior tranche with funds
        supplyFunds(takeAmount, address(junior));
        // deactivate borrow
        distributor.file("borrowFromTranches", false);
        balanceTake();
    }

    function testBalanceGive() public {
        uint giveAmount = 100 ether;
        // supply shelf with funds
        supplyFunds(giveAmount, address(shelf));
        // deactivate borrow
        distributor.file("borrowFromTranches", false);
        // take money from shelf and transfer into tranche
        balanceGive();
    }

    function testFailBalanceGiveShelfHasNoFunds() public {
        distributor.file("borrowFromTranches", false);
        // do not supply shelf with funds
        balanceGive();
    }

    function testFailBalanceGiveInactive() public {
         uint giveAmount = 100 ether;
        // supply shelf with funds
        supplyFunds(giveAmount, address(shelf));
        // do not deactivate borrow
        balanceGive();
    }
}