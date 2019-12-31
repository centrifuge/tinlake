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

    OperatorMock senior;
    OperatorMock junior;
    DistributorMock distributor;
    PileMock pile;
    TrancheManager manager;

    function setUp() public {
        senior = new OperatorMock();
        junior = new OperatorMock();
        distributor = new DistributorMock();
        pile = new PileMock();
        manager = new TrancheManager(address(pile));
    }

    function testSetTranches() public {
        manager.setTranche("junior", address(junior));
        manager.setTranche("senior", address(senior));
        assertEq(address(senior), address(manager.senior()));
        assertEq(address(junior), address(manager.junior()));

    }

    function testTrancheRatio() public {
        uint juniorRatio = 3 * 10**26; // 30% juniorRatio
        uint seniorRatio = 7 * 10**26; // 70% senior

        manager.file("juniorRatio", juniorRatio);

        assertEq(juniorRatio, manager.juniorRatio());
        assertEq(seniorRatio, manager.seniorRatio());
    }
}