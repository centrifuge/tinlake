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

import "../../../test/mock/operator.sol";
import "../distributor.sol";
import "../line.sol";
import "../fixed.sol";
import "../../../test/mock/pile.sol";
import "../../../test/mock/manager.sol";

contract DistributorTest is DSTest{

    OperatorMock oE;
    OperatorMock oS;
    PileMock pile;
    ManagerMock manager;

    Distributor distributor;
    LOC l;
    FixedCredit f;

    function setUp() public {
        oE = new OperatorMock();
        oS = new OperatorMock();
        pile = new PileMock();
        manager = new ManagerMock();

        distributor = createDistributor(address(manager));
        f = createFixedCreditDistribution(address(manager));
        l = createLineOfCreditDistribution(address(manager));


        addTranches();
    }

    function createDistributor(address manager_) internal returns (Distributor) {
        return new Distributor(manager_);
    }

    function createFixedCreditDistribution(address manager_) internal returns (FixedCredit) {
        return new FixedCredit(manager_);
    }

    function createLineOfCreditDistribution(address manager_) internal returns (LOC) {
        return new LOC(manager_);
    }

    function addTranches() public {
        manager.addTranche(70, address(oE));
        manager.addTranche(30, address(oS));
    }

    function testFixedBalance() public {
        manager.setPoolClosing(false);
        oE.setBalance(7);
        oS.setBalance(3);
        f.balance();
        assertEq(oE.callsBorrow(), 1);
        assertEq(oE.balanceOf(), 0);
        assertEq(oS.callsBorrow(), 1);
        assertEq(oS.balanceOf(), 0);

        // nothing in the operator balance so no calls should be made
        f.balance();
        assertEq(oE.callsBorrow(), 1);
        assertEq(oS.callsBorrow(), 1);
    }

    function testFailFixedBalancePoolClosing() public {
        manager.setPoolClosing(true);
        f.balance();
    }

    function testLOCBalance() public {
        manager.setPoolClosing(false);
        oE.setBalance(7);
        oS.setBalance(3);
        manager.setPileAmount(10);
        l.balance();
        assertEq(oE.callsBorrow(), 1);
        assertEq(oE.balanceOf(), 0);
        assertEq(oS.callsBorrow(), 1);
        assertEq(oS.balanceOf(), 0);

        manager.setPileAmount(-10);
        oS.setDebtOf(10);
        l.balance();
        assertEq(oS.callsRepay(), 1);
        assertEq(oS.balanceOf(), 10);
        assertEq(oS.debt(), 0);
        assertEq(oE.callsRepay(), 0);

        manager.setPileAmount(-10);
        oS.setDebtOf(5);
        oE.setDebtOf(8);
        l.balance();
        assertEq(oS.callsRepay(), 2);
        assertEq(oS.balanceOf(), 15);
        assertEq(oS.debt(), 0);
        assertEq(oE.callsRepay(), 1);
        assertEq(oE.balanceOf(), 5);
        assertEq(oE.debt(), 3);
    }

    function testFailLOCBalancePoolClosing() public {
        manager.setPoolClosing(true);
        l.balance();
    }

}
