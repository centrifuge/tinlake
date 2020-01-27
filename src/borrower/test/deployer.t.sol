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

pragma solidity >=0.5.3;

import "ds-test/test.sol";
import { Title } from "tinlake-title/title.sol";

import "../deployer.sol";
import { SimpleToken } from "../../test/simple/token.sol";

contract DeployerTest is DSTest {
    Title nft;
    SimpleToken dai;
    TitleFab titlefab;
    ShelfFab shelffab;
    PileFab pilefab;
    address ceilingFab_;
    CollectorFab collectorFab;
    ThresholdFab thresholdFab;
    PricePoolFab pricePoolFab;
    Title title;

    function setUp() public {
        nft = new Title("SimpleNFT", "NFT");
        dai = new SimpleToken("DDAI", "Dummy Dai", "1", 0);
        titlefab = new TitleFab();
        shelffab = new ShelfFab();
        pilefab = new PileFab();
        ceilingFab_ = address(new PrincipalCeilingFab());
        collectorFab = new CollectorFab();
        thresholdFab = new ThresholdFab();
        pricePoolFab = new PricePoolFab();
   }

    function testBorrowerDeploy() public logs_gas {
        BorrowerDeployer deployer = new BorrowerDeployer(address(0), titlefab, shelffab, pilefab, ceilingFab_, collectorFab, thresholdFab, pricePoolFab, address(dai), "Test", "TEST");

        deployer.deployTitle();
        deployer.deployPile();
        deployer.deployCeiling();
        deployer.deployShelf();
        deployer.deployThreshold();
        deployer.deployCollector();
        deployer.deployPricePool();

        deployer.deploy();
    }
}
