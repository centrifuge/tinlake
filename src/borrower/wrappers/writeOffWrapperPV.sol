// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "tinlake-auth/auth.sol";

interface NAVFeedPVLike {
    function writeOff(uint256 loan) external;
}

/// @notice WriteOff contract can move overdue loans into a write off group
/// The wrapper contract works specifically for the NAVFeedPV version
contract WriteOffWrapperPV is Auth {
    NAVFeedPVLike navFeed;

    constructor(address navFeed_) {
        navFeed = NAVFeedPVLike(navFeed_);
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    /// @notice writes off an overdue loan
    /// @param loan the id of the loan
    function writeOff(uint256 loan) public auth {
        navFeed.writeOff(loan)
    }
}
