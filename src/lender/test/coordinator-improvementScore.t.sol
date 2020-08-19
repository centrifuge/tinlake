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

contract CoordinatorImprovementScoreTest is CoordinatorTest {
    function setUp() public {
        super.setUp();

    }

    function testImprovement() public {
        uint maxReserve = 1300 ether;
        uint newReserve = 300 ether;

        newReserve = rdiv(newReserve, maxReserve);
        maxReserve = ONE;

        emit log_named_uint("inputReserve", newReserve);
        emit log_named_uint("maxReserve", maxReserve);


        uint currSeniorRatio = 90 * 10 **25;
        uint minSeniorRatio = 75 * 10 ** 25;
        uint maxSeniorRatio = 85 * 10 ** 25;

        currSeniorRatio = 92 * 10 **25;

        emit log_named_uint("distance", coordinator.abs(currSeniorRatio, safeDiv(safeAdd(minSeniorRatio, maxSeniorRatio), 2)));

         uint ratioScore = rmul(1000, rdiv(ONE, coordinator.abs(currSeniorRatio, safeDiv(safeAdd(minSeniorRatio, maxSeniorRatio), 2))));

        emit log_named_uint("distance:" ,rdiv(ONE,coordinator.abs(safeDiv(maxReserve,2), newReserve)));
        uint reserveScore = rmul(10, rdiv(ONE,coordinator.abs(safeDiv(maxReserve,2), newReserve)));

        emit log_named_uint("ratioScore", ratioScore);
        emit log_named_uint("reserveScore", reserveScore);

        //assertTrue(false);
    }

}

