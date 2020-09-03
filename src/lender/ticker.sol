// Copyright (C) 2020 Centrifuge
//
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

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

contract Ticker is Auth, Math {
    uint public firstEpochTimestamp;
    uint public epochCount;

    uint public epochTime = 1 days;

    constructor() public {
        // 00:00 next day first epoch starts
        firstEpochTimestamp = normalizeTimestamp(now);
        epochTime = 1 days;
    }

    function file(bytes32 name, uint value) public auth {
        if(name == "epochTime") {
            epochTime = value;
        } else {
            revert("unknown-name");
        }
    }

    // normalizes timestamp to 00:00
    function normalizeTimestamp(uint timestamp) public view returns (uint) {
        return safeMul((1 days), safeDiv(timestamp, epochTime));
    }

    function currentEpoch() public returns (uint) {
        return safeDiv(safeSub(normalizeTimestamp(now), firstEpochTimestamp), (1 days));
    }
}
