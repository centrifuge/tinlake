// Copyright (C) 2019 lucasvo

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

pragma solidity >=0.5.12;

import "tinlake-auth/auth.sol";

contract SwitchLike {
    function on() public returns (uint);
}

contract Switchable {
    // --- Data ---
    SwitchLike public lightswitch;
    
    constructor (address lightswitch_) public {
        lightswitch = SwitchLike(lightswitch_);
    }
    // --- Switchable ---
    modifier switchable { require(lightswitch.on() == 1); _; }
}

contract LightSwitch is Auth {

    // --- Data ---
    uint public on;

    constructor () public {
        wards[msg.sender] = 1;
        on = 1;
    }

    // --- LightSwitch ---
    function set(uint on_) public auth {
        require(on_ < 2);
        on = on_;
    }
}

