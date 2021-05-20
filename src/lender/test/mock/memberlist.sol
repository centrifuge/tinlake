// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";

import "../../../test/mock/mock.sol";

contract MemberlistMock is Mock, Auth {

    constructor() public {
        wards[msg.sender] = 1;
    }

    function updateMember(address usr, uint256 validUntil) public auth {
      calls["updateMember"]++;
      values_address["updateMember_usr"] = usr;
      values_uint["updateMember_validUntil"] = validUntil;
    }

    function updateMembers(address[] memory users, uint256 validUntil) public auth {
      calls["updateMembers"]++;

      for (uint i=0; i<users.length; i++) {
        values_address["updateMembers_usr"] = users[i];
        values_uint["updateMembers_validUntil"] = validUntil;
      }
    }
}
