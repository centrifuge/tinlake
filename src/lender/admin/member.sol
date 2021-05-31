// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";

interface MemberlistLike {
    function updateMember(address usr, uint validUntil) external;
    function updateMembers(address[] calldata users, uint validUntil) external;
}

// Wrapper contract for permission restriction on the memberlists.
contract MemberAdmin is Auth {
    constructor() {
        wards[msg.sender] = 1;
    }

    // Admins can manipulate memberlists, but have to be added and can be removed by any ward on the MemberAdmin contract
    mapping (address => uint) public admins;

    event RelyAdmin(address indexed usr);
    event DenyAdmin(address indexed usr);

    modifier admin { require(admins[msg.sender] == 1); _; }

    function relyAdmin(address usr) public auth {
        admins[usr] = 1;
        emit RelyAdmin(usr);
    }

    function denyAdmin(address usr) public auth {
        admins[usr] = 0;
        emit DenyAdmin(usr);
    }

    function updateMember(address list, address usr, uint validUntil) public admin {
        MemberlistLike(list).updateMember(usr, validUntil);
    }

    function updateMembers(address list, address[] memory users, uint validUntil) public admin {
        MemberlistLike(list).updateMembers(users, validUntil);
    }
}

