// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { Memberlist } from "./../token/memberlist.sol";

interface MemberlistFabLike {
    function newMemberlist() external returns (address);
}

contract MemberlistFab {
    function newMemberlist() public returns (address memberList) {
        Memberlist memberlist = new Memberlist();

        memberlist.rely(msg.sender);
        memberlist.deny(address(this));

        return (address(memberlist));
    }
}
