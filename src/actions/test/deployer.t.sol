// Copyright (C) 2019 Centrifuge GmbH

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

pragma solidity >=0.4.24;

import "ds-test/test.sol";

import { Title } from "../../title.sol";
import { Proxy, ProxyFactory } from "../proxy.sol";
import { ProxyRegistry } from "../registry.sol";
import "../deployer.sol";

contract DeployerTest is DSTest {
    TitleFab titlefab;
    FactoryFab factoryfab;
    RegistryFab registryfab;

    Title title;

    function setUp() public {
        titlefab = new TitleFab();
        factoryfab = new FactoryFab();
        registryfab = new RegistryFab();
    }

    function testDeploy() public logs_gas {
        Deployer deployer = new Deployer(address(0), titlefab, factoryfab, registryfab);
        deployer.deployTitle("Test", "TEST");
        deployer.deployProxyStation(deployer.title());
        deployer.deployProxy(deployer.registry());
    }
}