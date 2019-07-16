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
import "./mock/appraiser.sol";
import "./mock/admit.sol";
import "./mock/pile.sol";

contract AdminTest is DSTest {
    AdmitMock admit;
    PileMock pile;
    AppraiserMock appraiser;
    Admin admin;

    address self;

    function setUp() public {
        self = address(this);
        admit = new AdmitMock();
        pile = new PileMock();
        appraiser = new AppraiserMock();

        admin = new Admin(address(admit),address(appraiser), address(pile));
    }


    function whitelist(uint nft, address registry, uint principal, uint appraisal, uint fee, uint loan, uint pileCalls) public {
        admin.whitelist(registry, nft, principal,appraisal,fee, self);

        // check admit
        assertEq(admit.callsAdmit(),1);
        assertEq(admit.registry(), registry);
        assertEq(admit.nft(), nft);
        assertEq(admit.principal(),principal);
        assertEq(admit.usr(), self);

        // check pile
        assertEq(pile.callsFile(),pileCalls);
        if (pileCalls == 2) {
            assertEq(pile.speed(), fee);
        }
        assertEq(pile.loan(), loan);
        assertEq(pile.balance(), 0);
        assertEq(pile.fee(), fee);

        // check appraisal
        assertEq(appraiser.callsFile(), 1);
        assertEq(appraiser.value(), appraisal);
        assertEq(appraiser.loan(), loan);
    }


    function doWhitelist(uint shouldLoan, uint shouldPileCalls) public {
        uint nft = 1;
        address registry = 0x29C76e6aD8f28BB1004902578Fb108c507Be341b;
        uint principal = 500 ether;
        uint appraisal = 600 ether;
        uint fee = uint(1000000564701133626865910626); // 5 % / daily

        whitelist(nft, registry, principal, appraisal, fee, shouldLoan, shouldPileCalls);

    }

    // --Tests--
    function testFailWhitelist() public {
        // fee not initialized
        pile.setFeeReturn(0,0,0,0);
        uint shouldPileCalls = 1;

        uint shouldLoan = 97;
        admit.setAdmitReturn(shouldLoan);

        doWhitelist(shouldLoan, shouldPileCalls);
    }

    function testWhitelistWithoutFeeInit() public {
        uint shouldSpeed = uint(1000000564701133626865910626);
        pile.setFeeReturn(0,0,shouldSpeed,0);
        uint shouldPileCalls = 1;

        uint shouldLoan = 97;
        admit.setAdmitReturn(shouldLoan);

        doWhitelist(shouldLoan, shouldPileCalls);
    }

}
