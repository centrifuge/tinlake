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

import "tinlake-auth/auth.sol";

interface AssessorLike {
    function file(bytes32 name, uint256 value) external;
}

interface LendingAdapter {
    function raise(uint256 amountDAI) external;
    function sink(uint256 amountDAI) external;
}

contract MemberlistLike {
    function updateMember(address usr, uint256 validUntil) public;
    function updateMembers(address[] memory users, uint256 validUntil) public;
}

// Wrapper contract for various pool management tasks.
contract PoolAdmin is Auth {
  
    AssessorLike public assessor;
    LendingAdapter public lending;
    MemberlistLike public seniorMemberlist;
    MemberlistLike public juniorMemberlist;

    bool public live = true;

    // Admins can manage pools, but have to be added and can be removed by any ward on the PoolAdmin contract
    mapping(address => uint256) public admins;

    constructor() public {
        wards[msg.sender] = 1;
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else if (contractName == "lending") {
            lending = LendingAdapter(addr);
        } else if (contractName == "seniorMemberlist") {
            seniorMemberlist = MemberlistLike(addr);
        } else if (contractName == "juniorMemberlist") {
            juniorMemberlist = MemberlistLike(addr);
        } else revert();
    }

    function file(bytes32 what, bool data) public auth {
        live = data;
    }

    modifier admin { require(admins[msg.sender] == 1 && live); _; }

    function relyAdmin(address usr) public auth note {
        admins[usr] = 1;
    }

    function denyAdmin(address usr) public auth note {
        admins[usr] = 0;
    }

    // Manage max reserve
    function setMaxReserve(uint256 value) public admin {
        assessor.file("maxReserve", value);
    }

    // Manage creditline
    function raiseCreditline(uint256 amount) public admin {
        lending.raise(amount);
    }

    function sinkCreditline(uint256 amount) public admin {
        lending.sink(amount);
    }

    // Manage memberlists
    function updateSeniorMember(address usr, uint256 validUntil) public admin {
        seniorMemberlist.updateMember(usr, validUntil);
    }

    function updateSeniorMembers(address[] memory users, uint256 validUntil) public admin {
        seniorMemberlist.updateMembers(users, validUntil);
    }

    function updateJuniorMember(address usr, uint256 validUntil) public admin {
        juniorMemberlist.updateMember(usr, validUntil);
    }

    function updateJuniorMembers(address[] memory users, uint256 validUntil) public admin {
        juniorMemberlist.updateMembers(users, validUntil);
    }
    
}
