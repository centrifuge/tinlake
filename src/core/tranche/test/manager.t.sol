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

import "../../test/mock/operator.sol";
import "../../test/mock/distributor.sol";
import "../../test/mock/pile.sol";
import "../manager.sol";

contract TrancheManagerTest is DSTest {

    struct Tranche {
        uint ratio;
        OperatorLike operator;
    }

    OperatorMock o1;
    OperatorMock o2;
    DistributorMock distributor;
    PileMock pile;
    TrancheManager manager;

    function setUp() public {
        o1 = new OperatorMock();
        o2 = new OperatorMock();
        distributor = new DistributorMock();
        pile = new PileMock();
        manager = new TrancheManager(address(pile));
    }

    function testAddTranches() public {
        manager.addTranche(30, address(o1));
        assertEq(manager.trancheCount(), 1);

        manager.addTranche(70, address(o2));
        assertEq(manager.trancheCount(), 2);
        assertEq(manager.operatorOf(0), address(o1));
        assertEq(manager.operatorOf(1), address(o2));
        assertEq(manager.ratioOf(0), 30);
        assertEq(manager.ratioOf(1), 70);
    }

    function testBalance() public {
        manager.file("poolClosing", false);
        manager.depend("distributor", address(distributor));
        manager.balance();
        assertEq(distributor.callsBalance(), 1);
        assertEq(distributor.callsRepayTranches(), 0);

        manager.file("poolClosing", true);
        manager.balance();
        assertEq(distributor.callsBalance(), 1);
        assertEq(distributor.callsRepayTranches(), 1);
    }
}