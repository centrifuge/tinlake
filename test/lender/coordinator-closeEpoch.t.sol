// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "./coordinator-base.t.sol";

contract CoordinatorCloseEpochTest is CoordinatorTest {
    function setUp() public override {
        super.setUp();
        // set max available currency to 1 to check if it was set to 0 on close
        assessor.changeBorrowAmountEpoch(1);
    }

    function testMinimumEpochTime() public {
        assertEq(coordinator.lastEpochExecuted(), 0);
        assertEq(coordinator.currentEpoch(), 1);
        hevm.warp(block.timestamp + coordinator.minimumEpochTime());
        // close and execute because no submissions
        coordinator.closeEpoch();
        assertEq(coordinator.currentEpoch(), 2);
        assertEq(coordinator.lastEpochExecuted(), 1);
    }

    // close epoch unit tests
    function testFailCloseEpochTooEarly() public {
        hevm.warp(block.timestamp + 25 seconds);
        uint256 secsForNextDay = calcNextEpochIn();
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);

        // should fail one sec too early
        hevm.warp(block.timestamp + secsForNextDay - 1);
        coordinator.closeEpoch();
    }

    function testCloseEpochEdgeCase() public {
        uint256 secsForNextDay = calcNextEpochIn();
        assertEq(coordinator.currentEpoch(), 1);
        // exact 00:00 time
        hevm.warp(block.timestamp + secsForNextDay);

        coordinator.closeEpoch();
        assertEq(coordinator.currentEpoch(), 2);
    }

    function testCloseEpochAfterLongerTime() public {
        assertEq(coordinator.currentEpoch(), 1);
        // exact 00:00 time
        hevm.warp(block.timestamp + 300 days);

        assertEq(coordinator.currentEpoch(), 1);
        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 1);
        assertEq(coordinator.currentEpoch(), 2);
    }

    function testCloseEpochTime() public {
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(block.timestamp + 1 days);

        assertEq(coordinator.currentEpoch(), 1);
        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 1);

        hevm.warp(block.timestamp + 20 days);

        assertEq(coordinator.currentEpoch(), 2);

        for (uint256 i = 1; i <= 400; i++) {
            coordinator.closeEpoch();
            hevm.warp(block.timestamp + 1 days);
            assertEq(coordinator.lastEpochExecuted(), i + 1);
        }
    }

    function testCloseEpochNoSubmission() public {
        assertEq(assessor.values_uint("changeSeniorAsset_seniorRatio"), 0);
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(block.timestamp + 1 days);

        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 1);
        assertTrue(coordinator.submissionPeriod() == false);
    }

    function testCloseEpochSubmissionPeriod() public {
        // higher junior supply demand
        juniorTranche.setEpochReturn(1000000000000 ether, 0);
        assertEq(coordinator.currentEpoch(), 1);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(block.timestamp + 1 days);

        // only close not executed
        coordinator.closeEpoch();
        assertEq(coordinator.lastEpochExecuted(), 0);
        assertTrue(coordinator.submissionPeriod() == true);
        assertEq(assessor.values_uint("borrow_amount"), 0);
    }
}
