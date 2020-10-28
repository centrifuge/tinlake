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

import "./../assessor.sol";
import "./../admin/assessor.sol";


contract AssessorAdminTest is DSTest {

    Assessor assessor;
    AssessorAdmin assessorAdmin;

    address assessor_;
    address assessorAdmin_;

    function setUp() public {
        assessor = new Assessor();
        assessorAdmin = new AssessorAdmin();

        assessor_ = address(assessor);
        assessorAdmin_ = address(assessorAdmin);
        assessorAdmin.depend("assessor", assessor_);
    }

    function callMaxReserve() public {
        uint maxReserve = 150 ether;
        
        // call setMaxReserve 
        assessorAdmin.setMaxReserve(maxReserve);

        // assert maxReserve value was set
        assertEq(assessor.maxReserve(), maxReserve);
    }

    function testSetMaxReserve() public {
        // rely assessorAdmin on assessor
        assessor.rely(assessorAdmin_);
        callMaxReserve(); 
    }

    function testFailSetMaxReserveNoPermissions() public {
         // do not rely assessorAdmin on assessor
        callMaxReserve(); 
    }
}

