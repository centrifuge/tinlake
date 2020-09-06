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
import "../token/memberlist.sol";
import "tinlake-math/math.sol";


contract MemberlistTest is Math, DSTest {

    uint memberlistValidity = safeAdd(now, 8 days);
    Memberlist memberlist;

    address self;
    address memberlist_;

    function setUp() public {
        memberlist = new Memberlist();
        self = address(this);
        memberlist_ = address(memberlist);
    }

    function testAddMember() public {
        memberlist.updateMember(self, memberlistValidity);
        assertEq(memberlist.members(self), memberlistValidity);
    }

    function testFailAddMemberPeriodTooShort() public {
        uint memberlistValidity = safeAdd(now, 7 days);
        memberlist.updateMember(self, memberlistValidity);
    }

    function testUpdateMember() public {
        memberlist.updateMember(self, memberlistValidity);
        uint newMemberlistValidity = safeAdd(now, 9 days);
        memberlist.updateMember(self, newMemberlistValidity);
        assertEq(memberlist.members(self), newMemberlistValidity);
    }

    function testIsMember() public {
        memberlist.updateMember(self, memberlistValidity);
        memberlist.member(self);
    }

    function testFailIsMemberNotAdded() public {
        memberlist.member(self);
    }
}
