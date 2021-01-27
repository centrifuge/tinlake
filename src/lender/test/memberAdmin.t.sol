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

import "./../admin/member.sol";
import "./mock/memberlist.sol";


contract MemberAdminTest is DSTest {
    MemberAdmin memberAdmin;
    MemberlistMock memberlist;

    function setUp() public {
        memberAdmin = new MemberAdmin();
        memberlist = new MemberlistMock();
    }

    function test_updateMemberAsAdmin() public {
        memberAdmin.relyAdmin(address(this));

        address usr = 0x0A735602a357802f553113F5831FE2fbf2F0E2e0;
        uint validUntil = now + 365 days;
        memberAdmin.updateMember(address(memberlist), usr, validUntil);

        assertEq(memberlist.calls("updateMember"), 1);
        assertEq(memberlist.values_address("updateMember_usr"), usr);
        assertEq(memberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testFail_updateMemberAsNonAdmin() public {
        memberAdmin.denyAdmin(address(this));

        address usr = 0x0A735602a357802f553113F5831FE2fbf2F0E2e0;
        uint validUntil = now + 365 days;
        memberAdmin.updateMember(address(memberlist), usr, validUntil);

        assertEq(memberlist.calls("updateMember"), 1);
        assertEq(memberlist.values_address("updateMember_usr"), usr);
        assertEq(memberlist.values_uint("updateMember_validUntil"), validUntil);
    }
}