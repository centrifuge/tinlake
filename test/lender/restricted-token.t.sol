// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/math.sol";
import "src/lender/token/restricted.sol";
import "src/lender/token/memberlist.sol";

contract TestUser {}

interface Hevm {
    function warp(uint256) external;
}

contract RestrictedTokenTest is Math, Test {
    Hevm hevm;

    uint256 memberlistValidity;
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

        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(block.timestamp + 1 days);
        memberlistValidity = safeAdd(block.timestamp, 8 days);
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
