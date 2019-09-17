// Copyright (C) 2019 Centrifuge

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
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";

import { AdminProxy } from "./simple/adminproxy.sol";
import "./mock/admin.sol";

contract AdminProxyTest is DSTest {
    AdminProxy adminProxy;
    AdminMock admin;

    address self;

    function setUp() public {
        self = address(this);
        admin = new AdminMock();
        adminProxy = new AdminProxy(address(admin));
    }

    function whitelist(address registry, uint nft, uint principal, uint appraisal, uint fee) public {
        adminProxy.whitelist(registry, nft, principal, appraisal, fee, self);

        assertEq(admin.callsWhitelist(), 1);
        assertEq(admin.registry(), registry);
        assertEq(admin.nft(), nft);
        assertEq(admin.principal(),principal);
        assertEq(admin.appraisal(),appraisal);
        assertEq(admin.fee(),fee);
        assertEq(admin.usr(), self);
    }

    function doWhitelist() public {
        uint nft = 1;
        address registry = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        uint principal = 500 ether;
        uint appraisal = 600 ether;
        uint fee = uint(1000000564701133626865910626); // 5 % / daily
        whitelist(registry, nft, principal, appraisal, fee);
    }

    function testFailWhitelistNoPermissions() public {
        doWhitelist();
    }

    function testWhitelist() public {
        admin.rely(address(adminProxy));
        doWhitelist();
    }

}
