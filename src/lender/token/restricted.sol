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

import "tinlake-erc20/erc20.sol";

contract MemberlistLike {
    function member(address) public;
}

// Only mebmber with a valid (not expired) membership should be allowed to receive tokens
contract RestrictedToken is ERC20 {

    MemberlistLike public memberlist; 
    modifier checkMember(address usr) { memberlist.member(usr); _; }
    
    function hasMember(address usr) public returns (bool) {
        // will fail if user not member
        memberlist.member(usr);
    }

    constructor(string memory symbol_, string memory name_) ERC20(symbol, name) public {}

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "memberlist") { memberlist = MemberlistLike(addr); }
        else revert();
    }

    function transferFrom(address from, address to, uint wad) checkMember(to) public returns (bool) {
        return super.transferFrom(from, to, wad);
    }
}

