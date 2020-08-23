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

import { EpochCoordinator } from "./../coordinator.sol";
import "tinlake-erc20/erc20.sol";
import "../coordinator.sol";

contract CoordinatorFab {
    function newCoordinator(uint challengeTime) public returns (address) {
        EpochCoordinator coordinator = new EpochCoordinator(challengeTime);
        coordinator.rely(msg.sender);
        coordinator.deny(address(this));
        return address(coordinator);
    }
}
