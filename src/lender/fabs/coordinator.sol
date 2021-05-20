// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { EpochCoordinator } from "./../coordinator.sol";
import "tinlake-erc20/erc20.sol";
import "../coordinator.sol";

interface CoordinatorFabLike {
    function newCoordinator(uint) external returns (address);
}

contract CoordinatorFab {
    function newCoordinator(uint challengeTime) public returns (address) {
        EpochCoordinator coordinator = new EpochCoordinator(challengeTime);
        coordinator.rely(msg.sender);
        coordinator.deny(address(this));
        return address(coordinator);
    }
}
