// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

/// @notice mantains a authorized list of members
contract Memberlist is Math, Auth {
    uint256 constant minimumDelay = 7 days;

    // -- Members--
    mapping(address => uint256) public members;

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    /// @notice adds a user as a member for a certain period of time
    /// @param usr the address of the user
    /// @param validUntil the timestamp until the user is a member
    /// minimum 7 day since block.timestamp
    function updateMember(address usr, uint256 validUntil) public auth {
        require((safeAdd(block.timestamp, minimumDelay)) < validUntil);
        members[usr] = validUntil;
    }

    /// @notice adds multiple addresses as a member for a certain period of time
    /// @param users the addresses of the users
    /// @param validUntil the timestamp until the user is a member
    function updateMembers(address[] memory users, uint256 validUntil) public auth {
        for (uint256 i = 0; i < users.length; i++) {
            updateMember(users[i], validUntil);
        }
    }
    /// @notice checks if an address is a member otherwise reverts
    /// @param usr the address of the user which should be a member
    function member(address usr) public view {
        require((members[usr] >= block.timestamp), "not-allowed-to-hold-token");
    }

    /// @notice returns true if an address is a member
    /// @param usr the address of the user which should be a member
    /// @return isMember true if the user is a member
    function hasMember(address usr) public view returns (bool isMember) {
        if (members[usr] >= block.timestamp) {
            return true;
        }
        return false;
    }
}
