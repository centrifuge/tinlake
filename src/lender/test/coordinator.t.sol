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

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "./../coordinator.sol";
import "./mock/epoch-tranche.sol";
import "./mock/reserve.sol";


contract Hevm {
    function warp(uint256) public;
}

contract CoordinatorTest is DSTest, Math {

    Hevm hevm;
    EpochCoordinator coordinator;

    EpochTrancheMock seniorTranche;
    EpochTrancheMock juniorTranche;

    ReserveMock reserve;

    address seniorTranche_;
    address juniorTranche_;
    address reserve_;

    function setUp() public {
        seniorTranche = new EpochTrancheMock();
        juniorTranche = new EpochTrancheMock();
        reserve = new ReserveMock();
        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);
        reserve_ = address(reserve);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        coordinator = new EpochCoordinator();
        coordinator.depend("juniorTranche", juniorTranche_);
        coordinator.depend("seniorTranche", seniorTranche_);
        coordinator.depend("reserve", reserve_);

    }

    function testEpochExecuteTime() public {
        assertEq(coordinator.currentEpoch(), 0);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(now + 1 days);

        assertEq(coordinator.currentEpoch(), 1);
        coordinator.executeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 1);

        hevm.warp(now + 20 days);

        assertEq(coordinator.currentEpoch(), 21);
        coordinator.executeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 21);
    }

    function calcNextEpochIn() public view returns(uint) {
        return 1 days - (now - coordinator.normalizeTimestamp(now));
    }

    function testEpochTimeEdgeCase() public {
        uint secsForNextDay = calcNextEpochIn();
        assertEq(coordinator.currentEpoch(), 0);
        // exact 00:00 time
        hevm.warp(now + secsForNextDay);

        assertEq(coordinator.currentEpoch(), 1);
        coordinator.executeEpoch();
    }

    function testFailEpochTime() public {
        uint secsForNextDay = calcNextEpochIn();
        assertEq(coordinator.currentEpoch(), 0);
        assertEq(coordinator.lastEpochExecuted(), 0);

        // should fail one sec too early
        hevm.warp(now + secsForNextDay - 1);
        coordinator.executeEpoch();
    }


}

