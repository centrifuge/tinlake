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
        EpochTrancheMock seniorTranche = new EpochTrancheMock();
        EpochTrancheMock juniorTranche = new EpochTrancheMock();
        ReserveMock reserve = new ReserveMock();
        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);
        reserve_ = address(reserve);

        coordinator = new EpochCoordinator();
        coordinator.depend("juniorTranche", juniorTranche_);
        coordinator.depend("seniorTranche", seniorTranche_);
        coordinator.depend("reserve", reserve_);

    }

    function testEpochStarts() public {

    }
}

