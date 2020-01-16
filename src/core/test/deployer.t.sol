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

import "../deployer.sol";
import { SimpleNFT } from "./simple/nft.sol";
import { SimpleToken } from "./simple/token.sol";

contract DeployerTest is DSTest {
    SimpleNFT nft;
    SimpleToken dai;
    TitleFab titlefab;
    LightSwitchFab lightswitchfab;
    ShelfFab shelffab;
    TrancheManagerFab trancheManagerFab;
    AdmitFab admitfab;
    AdminFab adminfab;
    PileFab pilefab;
    PrincipalFab principalFab;
    CollectorFab collectorFab;
    ThresholdFab thresholdFab;
    Title title;

    function setUp() public {
        nft = new SimpleNFT();
        dai = new SimpleToken("DDAI", "Dummy Dai", "1", 0);
        titlefab = new TitleFab();
        lightswitchfab = new LightSwitchFab();
        shelffab = new ShelfFab();
        trancheManagerFab = new TrancheManagerFab();
        admitfab = new AdmitFab();
        adminfab = new AdminFab();
        pilefab = new PileFab();
        principalFab = new PrincipalFab();
        collectorFab = new CollectorFab();
        thresholdFab = new ThresholdFab();
   }

    function testDeploy() public logs_gas {
        Deployer deployer = new Deployer(address(0), titlefab, lightswitchfab, shelffab, trancheManagerFab, admitfab, adminfab, pilefab, principalFab, collectorFab, thresholdFab);

        deployer.deployTitle("Test", "TEST");
        deployer.deployPile();
        deployer.deployPrincipal();
        deployer.deployLightSwitch();
        deployer.deployShelf(address(dai));
        deployer.deployTrancheManager(address(dai));
        deployer.deployAdmit();
        deployer.deployAdmin();
        deployer.deployThreshold();
        deployer.deployCollector();

        deployer.deploy();
    }
}
