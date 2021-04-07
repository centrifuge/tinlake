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
import "./../admin/pool.sol";


contract PoolAdminTest is DSTest {

    Assessor assessor;
    PoolAdmin poolAdmin;

    address assessor_;
    address poolAdmin_;

    function setUp() public {
        assessor = new Assessor();
        poolAdmin = new PoolAdmin();

        assessor_ = address(assessor);
        poolAdmin_ = address(poolAdmin);
        poolAdmin.depend("assessor", assessor_);
    }

    function callMaxReserve() public {
        uint maxReserve = 150 ether;
        
        // call setMaxReserve 
        poolAdmin.setMaxReserve(maxReserve);

        // assert maxReserve value was set
        assertEq(assessor.maxReserve(), maxReserve);
    }

    function testSetMaxReserve() public {
        // rely poolAdmin on assessor and make this test an admin
        assessor.rely(poolAdmin_);
        poolAdmin.relyAdmin(address(this));

        callMaxReserve(); 
    }

    function testFailSetMaxReserveNoPermissions() public {
         // do not rely poolAdmin on assessor
        callMaxReserve(); 
    }

    function testFailSetMaxReserveNotAdmin() public {
         // do rely poolAdmin on assessor but do not make this test an admin
        assessor.rely(poolAdmin_);
        
        callMaxReserve(); 
    }

}

