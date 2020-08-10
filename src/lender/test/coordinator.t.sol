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
import "./mock/assessor.sol";

contract Hevm {
    function warp(uint256) public;
}

contract CoordinatorTest is DSTest, Math {
    Hevm hevm;
    EpochCoordinator coordinator;

    EpochTrancheMock seniorTranche;
    EpochTrancheMock juniorTranche;

    AssessorMock assessor;

    ReserveMock reserve;

    address seniorTranche_;
    address juniorTranche_;
    address reserve_;
    address assessor_;

    function setUp() public {
        seniorTranche = new EpochTrancheMock();
        juniorTranche = new EpochTrancheMock();
        reserve = new ReserveMock();
        assessor = new AssessorMock();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);
        reserve_ = address(reserve);
        assessor_ = address(assessor);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        coordinator = new EpochCoordinator();
        coordinator.depend("juniorTranche", juniorTranche_);
        coordinator.depend("seniorTranche", seniorTranche_);
        coordinator.depend("reserve", reserve_);
        coordinator.depend("assessor", assessor_);

        initDefaultConfig();

    }

    function initDefaultConfig() internal {
        assessor.setReturn("maxReserve", 10000 ether);
        assessor.setReturn("calcJuniorTokenPrice", ONE);
        assessor.setReturn("calcSeniorTokenPrice", ONE);
        assessor.setReturn("calcNAV", 800 ether);
        reserve.setReturn("balance", 200 ether);
        assessor.setReturn("seniorDebt", 700 ether);
        assessor.setReturn("seniorBalance", 100 ether);
        juniorTranche.setEpochReturn(100 ether, 100 ether);
        seniorTranche.setEpochReturn(500 ether, 500 ether);
    }
//
//    function testEpochExecuteTime() public {
//        assertEq(coordinator.currentEpoch(), 0);
//        assertEq(coordinator.lastEpochExecuted(), 0);
//        hevm.warp(now + 1 days);
//
//        assertEq(coordinator.currentEpoch(), 1);
//        coordinator.executeEpoch();
//        assertEq(coordinator.lastEpochExecuted(), 1);
//
//        hevm.warp(now + 20 days);
//
//        assertEq(coordinator.currentEpoch(), 21);
//
//        for (uint i =1; i<=20; i++) {
//            coordinator.executeEpoch();
//            assertEq(coordinator.lastEpochExecuted(), i+1);
//        }
//
//    }

    function calcNextEpochIn() public view returns(uint) {
        return 1 days - (now - coordinator.normalizeTimestamp(now));
    }

//    function testEpochTimeEdgeCase() public {
//        uint secsForNextDay = calcNextEpochIn();
//        assertEq(coordinator.currentEpoch(), 0);
//        // exact 00:00 time
//        hevm.warp(now + secsForNextDay);
//
//        assertEq(coordinator.currentEpoch(), 1);
//        coordinator.executeEpoch();
//    }
//
//    function testFailEpochTime() public {
//        uint secsForNextDay = calcNextEpochIn();
//        assertEq(coordinator.currentEpoch(), 0);
//        assertEq(coordinator.lastEpochExecuted(), 0);
//
//        // should fail one sec too early
//        hevm.warp(now + secsForNextDay - 1);
//        coordinator.executeEpoch();
//    }

    // only junior investment
    function testSimpleEpochExecute() public {
        uint totalCurrency = 100 ether;
        juniorTranche.setEpochReturn(totalCurrency, 0);
        assessor.setTokenPrice(seniorTranche_, ONE);
        assessor.setTokenPrice(juniorTranche_, ONE);
        assessor.setReturn("minSeniorRatio", 75 * 10**25);
        assessor.setReturn("maxSeniorRatio", 85 * 10**25);


    }

    function testSimpleClose() public {
        assertEq(coordinator.currentEpoch(), 0);
        assertEq(coordinator.lastEpochExecuted(), 0);
        hevm.warp(now + 1 days);

        coordinator.closeEpoch();
    }

    function logState() public {

    }

}

