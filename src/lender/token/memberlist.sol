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

import "tinlake-auth/auth.sol";
import "ds-test/test.sol";

contract Memberlist is Auth, DSTest {
    // -- Members--
    mapping (address => uint) public members;
    function addMember(address usr) public auth { 
        emit log_named_uint("moin", 1);
        members[usr] = 1;
     }
    function removeMember(address usr) public auth { members[usr] = 0; }

    constructor() public {
        wards[msg.sender] = 1;
    }
   
    function member(address user) public {
        require((members[msg.sender] == 1), "not-allowed-to-hold-token");
    }
}