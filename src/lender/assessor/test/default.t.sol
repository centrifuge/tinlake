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
import "../default.sol";
import "../../test/mock/pool.sol";
import "../../test/mock/tranche.sol";

contract AssessorLike {
    function calcAndUpdateTokenPrice(address tranche) public returns (uint);
}
contract TestTranche is TrancheMock {
    function doCalcTokenPrice(address assessor_) public returns (uint) {
        return AssessorLike(assessor_).calcAndUpdateTokenPrice(address(this));
    }
}

contract Hevm {
    function warp(uint256) public;
}

contract DefaultAssessorTest is DSTest, Math {
    uint256 constant ONE = 10 ** 27;
    DefaultAssessor assessor;
    address assessor_;
    PoolMock pool;
    TestTranche senior = new TestTranche();
    TestTranche junior = new TestTranche();

    Hevm hevm;

    function setUp() public {
        pool = new PoolMock();
        assessor = new DefaultAssessor(1);
        assessor_ = address(assessor);
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        assessor.depend("junior", address(junior));
        // test simulates senior tranche
        assessor.depend("senior", address(this));
    }

    // simulate tranche behaviour
    uint public borrowed;
    uint public interest;
    uint public ratePerSecond;
    uint public lastUpdated;
    uint public balance;

    function debt() public view returns(uint){
        return borrowed+interest;
    }

    function testAccureTrancheInterest() public {
        ratePerSecond = 1000000564701133626865910626;// 5% per day
        borrowed = 100 ether;
        lastUpdated = now;

        // one day
        hevm.warp(now + 1 days);
        uint expectedInterest = 5 ether;
        interest = assessor.accrueTrancheInterest(address(this));
        assertEq(interest, expectedInterest);
        lastUpdated = now;

        // two days
        hevm.warp(now + 1 days);
        interest = assessor.accrueTrancheInterest(address(this));
        expectedInterest = 5.25 ether;
        assertEq(interest, expectedInterest);

        assertEq(assessor.accrueTrancheInterest(address(junior)), 0);
    }
}
