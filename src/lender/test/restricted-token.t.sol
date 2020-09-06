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

import "ds-test/test.sol";
import "../token/restricted.sol";
import "../token/memberlist.sol";
import "tinlake-math/math.sol";

contract TestUser {
}

contract Hevm {
    function warp(uint256) public;
}

contract RestrictedTokenTest is Math, DSTest {

    Hevm hevm;
    
    uint256 constant ONE = 10 ** 27;
    uint memberlistValidity = safeAdd(now, 8 days);
    Memberlist memberlist;
    RestrictedToken token;

    address self;
    address memberlist_;
    address token_;
    address randomUser_;

    function setUp() public {
        memberlist = new Memberlist();
        token = new RestrictedToken("TST", "TST");
        token.depend("memberlist", address(memberlist));
        
        TestUser randomUser = new TestUser();
        randomUser_ = address(randomUser);

        self = address(this);
        memberlist_ = address(memberlist);
        token_ = address(token_);

        token.mint(self, 100 ether);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(block.timestamp);
    }

    function testReceiveTokens() public {
        memberlist.updateMember(randomUser_, memberlistValidity);
        assertEq(memberlist.members(randomUser_), memberlistValidity);
        token.transferFrom(self, randomUser_, 50 ether);
        assertEq(token.balanceOf(randomUser_), 50 ether);
    }

    function testFailReceiveTokensNotMember() public {
        // random user not member
        token.transferFrom(self, randomUser_, 50 ether);
    }

   function testFailReceiveTokensMembershipExpired() public {
        // membership expires in 8 days
        memberlist.updateMember(randomUser_, memberlistValidity);
        assertEq(memberlist.members(randomUser_), memberlistValidity);

        // 9 days pass
        hevm.warp(safeAdd(block.timestamp, 9 days));

        // membership expired -> trabsfer should fail
        token.transferFrom(self, randomUser_, 20 ether);
    }
}
