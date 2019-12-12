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
import "../appraiser.sol";
import { SimpleNFT } from "./simple/nft.sol";
import { SimpleToken } from "./simple/token.sol";

contract DeployerTest is DSTest {
    SimpleNFT nft;
    SimpleToken dai;
    Appraiser appraiser;
    TitleFab titlefab;
    LightSwitchFab lightswitchfab;
    PileFab pilefab;
    ShelfFab shelffab;
    DeskFab deskfab;
    AdmitFab admitfab;
    AdminFab adminfab;
    BeansFab beansfab;

    Title title;

    function setUp() public {
        nft = new SimpleNFT();
        dai = new SimpleToken("DDAI", "Dummy Dai", "1", 0);
        appraiser = new Appraiser();
        titlefab = new TitleFab();
        lightswitchfab = new LightSwitchFab();
        pilefab = new PileFab();
        shelffab = new ShelfFab();
        deskfab = new DeskFab();
        admitfab = new AdmitFab();
        adminfab = new AdminFab();
        beansfab = new BeansFab();
   }
    
    function testDeploy() public logs_gas {
        Deployer deployer = new Deployer(address(0), titlefab, lightswitchfab, pilefab, shelffab, deskfab, admitfab, adminfab, beansfab);

        appraiser.rely(address(deployer));

        deployer.deployTitle("Test", "TEST");
        deployer.deployBeans();
        deployer.deployLightSwitch();
        deployer.deployPile(address(dai));
        deployer.deployShelf(address(appraiser));
        deployer.deployDesk(address(dai));
        deployer.deployAdmit();
        deployer.deployAdmin(address(appraiser));
        deployer.deploy();
    }
}
