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

pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "./../admin/member.sol";
import "./mock/memberlist.sol";


contract MemberAdminTest is DSTest {
    MemberAdmin memberAdmin;
    MemberlistMock memberlist;
    address[] users;

    function setUp() public {
        memberAdmin = new MemberAdmin();
        memberlist = new MemberlistMock();
        memberlist.rely(address(memberAdmin));

        users = new address[](3);
        users[0] = address(1);
        users[1] = address(2);
        users[2] = address(3);
    }

    function updateMember() public {
        address usr = address(1);
        uint validUntil = now + 365 days;
        memberAdmin.updateMember(address(memberlist), usr, validUntil);

        assertEq(memberlist.calls("updateMember"), 1);
        assertEq(memberlist.values_address("updateMember_usr"), usr);
        assertEq(memberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateMemberAsAdmin() public {
        memberAdmin.relyAdmin(address(this));
        updateMember();
    }

    function testFailUpdateMemberAsNonAdmin() public {
        memberAdmin.denyAdmin(address(this));
        updateMember();
    }

    function updateMembers() public {
        uint validUntil = now + 365 days;
        memberAdmin.updateMembers(address(memberlist), users, validUntil);

        assertEq(memberlist.calls("updateMembers"), 1);
        assertEq(memberlist.values_address("updateMember_usr"), users[users.length]);
        assertEq(memberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateMembersAsAdmin() public {
        memberAdmin.relyAdmin(address(this));
        updateMember();
    }

    function testFailUpdateMembersAsNonAdmin() public {
        memberAdmin.denyAdmin(address(this));
        updateMember();
    }
}