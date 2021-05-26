// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "../token/memberlist.sol";
import "tinlake-math/math.sol";


contract MemberlistTest is Math, DSTest {

    uint memberlistValidity = safeAdd(block.timestamp, 8 days);
    Memberlist memberlist;
    Memberlist testMemberlist;
    Memberlist testMemberlist1;

    address self;
    address memberlist_;
    address[] members;

    function setUp() public {
        memberlist = new Memberlist();
        self = address(this);
        memberlist_ = address(memberlist);
        members = new address[](3);
        members[0] = address(1);
        members[1] = address(2);
        members[2] = address(3);
    }

    function testAddMember() public {
        memberlist.updateMember(self, memberlistValidity);
        assertEq(memberlist.members(self), memberlistValidity);
    }

    function testAddMembers() public {
        memberlist.updateMembers(members, memberlistValidity);
        assertEq(memberlist.members(address(1)), memberlistValidity);
        assertEq(memberlist.members(address(2)), memberlistValidity);
        assertEq(memberlist.members(address(3)), memberlistValidity);
    }

    function testFailAddMemberPeriodTooShort() public {
        uint memberlistValidity_ = safeAdd(block.timestamp, 7 days);
        memberlist.updateMember(self, memberlistValidity_);
    }

    function testUpdateMember() public {
        memberlist.updateMember(self, memberlistValidity);
        uint newMemberlistValidity_ = safeAdd(block.timestamp, 9 days);
        memberlist.updateMember(self, newMemberlistValidity_);
        assertEq(memberlist.members(self), newMemberlistValidity_);
    }

    function testIsMember() public {
        memberlist.updateMember(self, memberlistValidity);
        memberlist.member(self);
        assert(memberlist.hasMember(self));
    }

    function testFailIsMemberNotAdded() public view {
        memberlist.member(self);
    }   

    function testFailHasMemberNotAdded() public view {
         assert(memberlist.hasMember(self));
    }   
}
