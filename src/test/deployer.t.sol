// Copyright (C) 2019 lucasvo

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
import "../collateral.sol";

contract LenderMock {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    address public tkn;
    address public collateral;
    
    constructor (address tkn_, address collateral_) public {
        wards[msg.sender] = 1;
        tkn = tkn_;
        collateral = collateral_;
    }

    // --- Lender Methods ---
    function provide(address usrC, address usrT, uint wadC, uint wadT) public { 
        revert();
    }

    function remove(address usrC, address usrT, uint wadC, uint wadT) public {
        revert();
    }

    function free(address usr, uint wad) public { 
        revert();
    }
}

contract LenderFabMock {
    function deploy(address tkn_, address collateral_, address lightswitch_) public returns (address) {
        LenderMock lender = new LenderMock(tkn_, collateral_);
        lender.rely(msg.sender);
        return address(lender);
    }
}

contract DeployerTest is DSTest {
    SimpleNFT nft;
    SimpleToken dai;
    address lenderfab;
    Appraiser appraiser;
    TitleFab titlefab;
    LightSwitchFab lightswitchfab;
    PileFab pilefab;
    ShelfFab shelffab;
    CollateralFab collateralfab;
    DeskFab deskfab;
    AdmitFab admitfab;
    AdminFab adminfab;

    function setUp() public {
        nft = new SimpleNFT();
        dai = new SimpleToken("DDAI", "Dummy Dai", "1", 0);
        lenderfab = address(new LenderFabMock());
        appraiser = new Appraiser();
        titlefab = new TitleFab();
        lightswitchfab = new LightSwitchFab();
        pilefab = new PileFab();
        shelffab = new ShelfFab();
        collateralfab = new CollateralFab();
        deskfab = new DeskFab();
        admitfab = new AdmitFab();
        adminfab = new AdminFab();
   }
    
    function testDeploy() public logs_gas {
        Deployer deployer = new Deployer(address(0), titlefab, lightswitchfab, pilefab, shelffab, collateralfab, deskfab,admitfab, adminfab);

        appraiser.rely(address(deployer));

        deployer.deployTitle("Test", "TEST");
        deployer.deployLightSwitch();
        deployer.deployCollateral();
        deployer.deployPile(address(dai));
        deployer.deployShelf(address(appraiser));
        deployer.deployValve();
        deployer.deployDesk();
        deployer.deployAdmit();
        deployer.deployAdmin(address(appraiser));
        deployer.deploy();
        deployer.deployLender(address(dai), address(lenderfab));
    }
}
