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

import "ds-test/test.sol";

import { SystemTest, ERC20Like } from "../core/test/system/system.t.sol";
import { Deployer } from "../core/deployer.sol";
import { ProxyDeployer, AccessRegistryFab, RegistryFab, FactoryFab } from "../proxy/deployer.sol";
import { Title } from "../core/title.sol";
import { Actions } from "../actions/actions.sol";
import { Proxy } from "../proxy/proxy.sol";
import { User } from "./user.sol";
import "./functional.t.sol";
import {CollectDeployer} from "../core/collect/deployer.sol";


contract CollectTest is FunctionalTest {
    function setUp() public {
        basicSetup();
    }

    function testBasicCollect() public {
        (uint tokenId, uint principal, uint appraisal, uint fee) = systemTest.defaultLoan();
        uint loan = whitelistAndBorrow(tokenId, principal, appraisal, fee);

        CollectDeployer collectDeployer = CollectDeployer(address(systemTest.deployer().collectDeployer()));

        // threshold 120%
        assertEq(collectDeployer.spotter().threshold(), 12 * 10**26);
        // current ratio 120%
        //assertEq(rdiv(appraisal, principal));

        bool seizable = collectDeployer.spotter().seizable(loan);
        assertTrue(seizable==false);

        systemTest.hevm().warp(now + 10 days);

        seizable = collectDeployer.spotter().seizable(loan);
        assertTrue(seizable==true);

    }
}

