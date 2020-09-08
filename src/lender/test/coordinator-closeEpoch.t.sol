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
pragma experimental ABIEncoderV2;

import "./coordinator-base.t.sol";

contract CoordinatorCloseEpochTest is CoordinatorTest {
    function setUp() public {
        super.setUp();
        // set max available currency to 1 to check if it was set to 0 on close
        reserve.file("currencyAvailable", 1);
    }

    function testMinimumEpochTime() public {
        assertEq(coordinator.lastEpochExecuted(), 0);
        assertEq(coordinator.currentEpoch(), 1);
        hevm.warp(now + 1 days);
        // close and execute because no submissions
        coordinator.closeEpoch();
        assertEq(coordinator.currentEpoch(), 2);
        assertEq(coordinator.lastEpochExecuted(), 1);
    }

   // close epoch unit tests
    function testFailCloseEpochTooEarly() public {
        hevm.warp(now + 25 seconds);
        uint secsForNextDay = calcNextEpochIn();
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);

        // should fail one sec too early
        hevm.warp(now + secsForNextDay-1);
        coordinator.closeEpoch();
    }

    function testCloseEpochEdgeCase() public {
        uint secsForNextDay = calcNextEpochIn();
        assertEq(coordinator.currentEpoch(), 1);
        // exact 00:00 time
        hevm.warp(now + secsForNextDay);

        coordinator.closeEpoch();
        assertEq(coordinator.currentEpoch(), 2);
    }

    function testCloseEpochAfterLongerTime() public {
        uint secsForNextDay = calcNextEpochIn();
        assertEq(coordinator.currentEpoch(), 1);
        // exact 00:00 time
        hevm.warp(now + 300 days);

        assertEq(coordinator.currentEpoch(), 1);
        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 1);
        assertEq(coordinator.currentEpoch(), 2);
    }

    function testCloseEpochTime() public {
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(now + 1 days);

        assertEq(coordinator.currentEpoch(), 1);
        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 1);

        hevm.warp(now + 20 days);

        assertEq(coordinator.currentEpoch(), 2);

        for (uint i =1; i<=400; i++) {
            coordinator.closeEpoch();
            hevm.warp(now + 1 days);
            assertEq(coordinator.lastEpochExecuted(), i+1);
        }
    }

    function testCloseEpochNoSubmission() public {
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(now + 1 days);

        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 1);
        assertTrue(coordinator.submissionPeriod() == false);
    }

    function testCloseEpochSubmissionPeriod() public {
        // higher junior supply demand
        juniorTranche.setEpochReturn(1000000000000 ether, 0);
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(now + 1 days);

        // only close not executed
        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 0);
        assertTrue(coordinator.submissionPeriod() == true);
        assertEq(reserve.values_uint("currency_available"), 0);
    }
}

