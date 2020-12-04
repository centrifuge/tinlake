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
import "../adapters/clerk.sol";
import "tinlake-math/math.sol";

import "../../test/simple/token.sol";
import "../test/mock/distributor.sol";
import "../test/mock/coordinator.sol";
import "../test/mock/navFeed.sol";
import "../test/mock/mgr.sol";
import "../test/mock/assessor.sol";
import "../test/mock/tranche.sol";

contract Hevm {
    function warp(uint256) public;
}

contract ClerkTest is Math, DSTest {

    Hevm hevm;
    
    uint256 constant ONE = 10 ** 27;
   
    Clerk clerk;

    SimpleToken currency;
    DistributorMock reserve;
    ManagerMock mgr;
    AssessorMock assessor;
    CoordinatorMock coordinator;
    NAVFeedMock nav;
    TrancheMock tranche;

    address self;

    function setUp() public {
        currency = new SimpleToken("DAI", "DAI");
        reserve = new DistributorMock(address(currency));
        mgr = new ManagerMock();
        assessor = new AssessorMock();
        coordinator = new CoordinatorMock();
        nav = new NAVFeedMock();
        tranche = new TrancheMock();
                    
        clerk = new Clerk(address(mgr), address(currency), address(assessor), address(coordinator), address(reserve), address(nav), address(tranche));
        self = address(this);
      
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(block.timestamp);
    }

    function testRise() public {
      
    }
}
