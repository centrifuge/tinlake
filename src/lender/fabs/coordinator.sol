// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import {EpochCoordinator} from "./../coordinator.sol";
import "tinlake-erc20/erc20.sol";
import "../coordinator.sol";

interface CoordinatorFabLike {
    function newCoordinator(uint256) external returns (address);
}

contract CoordinatorFab {
    function newCoordinator(uint256 challengeTime) public returns (address) {
        EpochCoordinator coordinator = new EpochCoordinator(challengeTime);
        coordinator.rely(msg.sender);
        coordinator.deny(address(this));
        return address(coordinator);
    }
}
