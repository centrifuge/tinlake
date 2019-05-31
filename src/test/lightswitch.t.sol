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

pragma solidity >=0.4.23;

import "ds-test/test.sol";

import "../lightswitch.sol";

contract Switched is Switchable {
    constructor (address lightswitch) Switchable(lightswitch) public {
    }
    function pass() public switchable {
    }
}
contract LightSwitchTest is DSTest {
    address self;
    LightSwitch lightswitch;
    Switched switched;

    function setUp() public {
        self = address(this);
        lightswitch = new LightSwitch();
        switched = new Switched(address(lightswitch));
    }

    function testSwitchedPass() public {
        lightswitch.set(1);
        switched.pass();
    }
    function testFailSwitchPass() public {
        lightswitch.set(0);
        switched.pass();
    }
}
