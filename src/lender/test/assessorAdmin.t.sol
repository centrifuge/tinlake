// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

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

