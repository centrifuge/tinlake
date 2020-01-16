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

import { Admin } from "../admin.sol";
import "./mock/admit.sol";
import "./mock/shelf.sol";
import "./mock/pile.sol";

contract AdminTest is DSTest {
    AdmitMock admit;
    PileMock pile;
    Admin admin;

    address self;

    function setUp() public {
        self = address(this);
        admit = new AdmitMock();
        pile = new PileMock();
        admin = new Admin(address(admit), address(pile));
    }

    function whitelist(uint nft, address registry, uint principal, uint rate, uint loan) public {
        admin.whitelist(registry, nft, principal, rate, self);

        // check admit
        assertEq(admit.callsAdmit(),1);
        assertEq(admit.registry(), registry);
        assertEq(admit.nft(), nft);
        assertEq(admit.principal(),principal);
        assertEq(admit.usr(), self);

        // check pile   
        assertEq(pile.callsSetRate(), 1);
        assertEq(pile.rate(), rate);
        assertEq(pile.loan(), loan);
    }

    function _doWhitelist(uint loan, uint rate) internal {
        uint nft = 1;
        address registry = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        uint principal = 500 ether;
        admit.setAdmitReturn(loan);
        whitelist(nft, registry, principal, rate, loan);
    }

    function testWhitelist() public {
        uint loan = 5;
        uint rate = uint(1000000564701133626865910626); // 5 % / daily
        pile.setRateReturn(0, 0, rate, 0);
        _doWhitelist(loan, rate);
    }
    // --Tests--
    function testFailWhitelist() public {
        uint loan = 5;
        uint rate = uint(1000000564701133626865910626); // 5 % / daily
        _doWhitelist(loan, rate);
    }

    function testFileRate() public {
        uint rate = uint(1000000564701133626865910626);
        admin.file(rate, rate);
        assertEq(pile.callsFile(), 1);
        assertEq(pile.speed(), rate);
        assertEq(pile.rate(), rate);
    }

    function testUpdateBlackList() public {
        uint loan = 5;
        uint rate = uint(1000000564701133626865910626); // 5 % / daily
        pile.setRateReturn(0, 0, rate, 0);
        _doWhitelist(loan, rate);

        // first update
        uint principal = 1500 ether;

        admin.update(loan, principal);

        assertEq(admit.callsUpdate(), 1);
        assertEq(admit.principal(), principal);

        // second update
        principal = 1000 ether;
        uint nft = 13;
        address registry = address(1);

        admin.update(loan, registry, nft, principal, rate);
        assertEq(admit.callsUpdate(), 2);
        assertEq(admit.principal(),principal);
        assertEq(admit.nft(), nft);
        assertEq(admit.registry(), registry);
        assertEq(pile.rate(), rate);

        // blacklist
        admin.blacklist(loan);

        assertEq(admit.callsUpdate(), 3);
        assertEq(admit.principal(), 0);
        assertEq(admit.nft(), 0);
        assertEq(admit.registry(), address(0));
        
        assertEq(pile.rate(), 0);
    }
}
