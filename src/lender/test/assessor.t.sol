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

import "./../assessor.sol";
import "./mock/tranche.sol";
import "./mock/navFeed.sol";

contract Hevm {
    function warp(uint256) public;
}

contract AssessorTest is DSTest, Math {
    Hevm hevm;
    Assessor assessor;
    TrancheMock seniorTranche;
    TrancheMock juniorTranche;
    NAVFeedMock navFeed;

    address seniorTranche_;
    address juniorTranche_;
    address navFeed_;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        seniorTranche = new TrancheMock();
        juniorTranche = new TrancheMock();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);

        navFeed = new NAVFeedMock();
        navFeed_ = address(navFeed);
        assessor = new Assessor();

        assessor.depend("juniorTranche", juniorTranche_);
        assessor.depend("seniorTranche", seniorTranche_);
        assessor.depend("navFeed", navFeed_);
    }

    function testCurrentNAV() public {
        navFeed.setReturn("calcUpdateNAV", 100 ether);
        assertEq(assessor.calcUpdateNAV(), 100 ether);
    }

    function testFileAssessor() public {
        uint maxReserve = 10000 ether;
        uint maxSeniorRatio = 80 * 10 **25;
        uint minSeniorRatio = 75 * 10 **25;
        uint seniorInterestRate = 1000000593415115246806684338; // 5% per day

        assessor.file("seniorInterestRate", seniorInterestRate);
        assertEq(assessor.seniorInterestRate(), seniorInterestRate);

        assessor.file("maxReserve", maxReserve);
        assertEq(assessor.maxReserve(), maxReserve);

        assessor.file("maxSeniorRatio", maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);

        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testFailFileMinRatio() public {
        // min needs to be smaller than max
        uint minSeniorRatio = 75 * 10 **25;
        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testFailFileMaxRatio() public {
        // min needs to be smaller than max
        uint minSeniorRatio = 75 * 10 **25;
        uint maxSeniorRatio = 80 * 10 **25;

        assessor.file("maxSeniorRatio", maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);

        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);

        // should fail
        assessor.file("maxSeniorRatio", minSeniorRatio-1);
    }

    function testChangeSeniorAsset() public {
        navFeed.setReturn("approximatedNAV", 100 ether);
        uint amount = 100 ether;
        // if seniorRatio 80% => NAV+reserve = 125 ether (100 ether already in reserve)
        uint seniorDebtRatio = 8 * 10 ** 26;
        assessor.increaseSeniorAsset(amount, seniorDebtRatio);

        // 80% of NAV
        assertEq(assessor.seniorDebt(), 80 ether);
        // rest
        assertEq(assessor.seniorBalance_(), 20 ether);

        amount = 50 ether;
        // NAV only depends on ongoing loans can be any value
        navFeed.setReturn("approximatedNAV", 10 ether);
        assessor.decreaseSeniorAsset(50 ether, 4 * 10 ** 26);
        // 40 % of NAV
        assertEq(assessor.seniorDebt(), 4 ether);
        assertEq(assessor.seniorBalance_(), 46 ether);
    }
}
