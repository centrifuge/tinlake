// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";

import "src/lender/admin/member.sol";
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
        uint validUntil = block.timestamp + 365 days;
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
        uint validUntil = block.timestamp + 365 days;
        memberAdmin.updateMembers(address(memberlist), users, validUntil);

        assertEq(memberlist.calls("updateMembers"), 1);
        assertEq(memberlist.values_address("updateMembers_usr"), address(3));
        assertEq(memberlist.values_uint("updateMembers_validUntil"), validUntil);
    }

    function testUpdateMembersAsAdmin() public {
        memberAdmin.relyAdmin(address(this));
        updateMembers();
    }

    function testFailUpdateMembersAsNonAdmin() public {
        memberAdmin.denyAdmin(address(this));
        updateMembers();
    }
}