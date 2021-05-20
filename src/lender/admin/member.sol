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

