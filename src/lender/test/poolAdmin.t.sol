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
import "./mock/memberlist.sol";

contract PoolAdminTest is DSTest {

    Assessor assessor;
    PoolAdmin poolAdmin;
    MemberlistMock seniorMemberlist;
    MemberlistMock juniorMemberlist;

    address[] users;

    function setUp() public {
        assessor = new Assessor();
        seniorMemberlist = new MemberlistMock();
        juniorMemberlist = new MemberlistMock();
        poolAdmin = new PoolAdmin();

        assessor.rely(address(poolAdmin));
        seniorMemberlist.rely(address(poolAdmin));
        juniorMemberlist.rely(address(poolAdmin));

        users = new address[](3);
        users[0] = address(1);
        users[1] = address(2);
        users[2] = address(3);

        poolAdmin.depend("assessor", address(assessor));
        poolAdmin.depend("seniorMemberlist", address(seniorMemberlist));
        poolAdmin.depend("juniorMemberlist", address(juniorMemberlist));
    }

    // Test setting max reserve
    function callMaxReserve() public {
        uint maxReserve = 150 ether;
        
        poolAdmin.setMaxReserve(maxReserve);
        assertEq(assessor.maxReserve(), maxReserve);
    }

    function testSetMaxReserve() public {
        poolAdmin.relyAdmin(address(this));
        callMaxReserve(); 
    }

    function testFailSetMaxReserveNotAdmin() public {
        callMaxReserve(); 
    }

    // TODO: test lending adapter

    // Test senior memberlist
    function updateSeniorMember() public {
        address usr = address(1);
        uint validUntil = now + 365 days;
        poolAdmin.updateSeniorMember(usr, validUntil);

        assertEq(seniorMemberlist.calls("updateMember"), 1);
        assertEq(seniorMemberlist.values_address("updateMember_usr"), usr);
        assertEq(seniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateSeniorMemberAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateSeniorMember();
    }

    function testFailUpdateSeniorMemberAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateSeniorMember();
    }

    function updateSeniorMembers() public {
        uint validUntil = now + 365 days;
        poolAdmin.updateSeniorMembers(users, validUntil);

        assertEq(seniorMemberlist.calls("updateMembers"), 1);
        assertEq(seniorMemberlist.values_address("updateMember_usr"), users[users.length]);
        assertEq(seniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateSeniorMembersAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateSeniorMember();
    }

    function testFailUpdateSeniorMembersAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateSeniorMember();
    }

    // Test junior memberlist
    function updateJuniorMember() public {
        address usr = address(1);
        uint validUntil = now + 365 days;
        poolAdmin.updateJuniorMember(usr, validUntil);

        assertEq(juniorMemberlist.calls("updateMember"), 1);
        assertEq(juniorMemberlist.values_address("updateMember_usr"), usr);
        assertEq(juniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateJuniorMemberAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateJuniorMember();
    }

    function testFailUpdateJuniorMemberAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateJuniorMember();
    }

    function updateJuniorMembers() public {
        uint validUntil = now + 365 days;
        poolAdmin.updateJuniorMembers(users, validUntil);

        assertEq(juniorMemberlist.calls("updateMembers"), 1);
        assertEq(juniorMemberlist.values_address("updateMember_usr"), users[users.length]);
        assertEq(juniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateJuniorMembersAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateJuniorMember();
    }

    function testFailUpdateJuniorMembersAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateJuniorMember();
    }

}

