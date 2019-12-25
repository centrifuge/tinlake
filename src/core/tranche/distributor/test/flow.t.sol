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

import "../flow.sol";

contract Distribution is Flowable {
    constructor (address flow_) Flowable(flow_) public {
    }
    function lineOfCredit() public line {
    }
    function fixedCredit() public fix {
    }
}
contract FlowTest is DSTest {
    Flow flow;
    Distribution distribution;

    function setUp() public {
        flow = new Flow();
        distribution = new Distribution(address(flow));
    }

    function testDistributionPass() public {
        flow.file("distribution", 0);
        distribution.lineOfCredit();
        flow.file("distribution", 1);
        distribution.fixedCredit();
    }
    function testFailDistributionL() public {
        flow.file("distribution", 1);
        distribution.lineOfCredit();
    }
    function testFailDistributionF() public {
        flow.file("distribution", 0);
        distribution.fixedCredit();
    }
}