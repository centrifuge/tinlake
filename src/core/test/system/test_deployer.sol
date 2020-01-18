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

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import { Title } from "tinlake-title/title.sol";
import "../../borrower/deployer.sol";
import "../../lender/deployer.sol";
import "../../deployer.sol";

import "../simple/token.sol";

contract TestDeployer  {
    Title public collateralNFT;
    address      public collateralNFT_;
    SimpleToken  public currency;
    address      public currency_;
    BorrowerDeployer     public borrowerDeployer;

    MainDeployer mainDeployer;
    address mainDeployer_;


    function setUp() public {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);

        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);

        mainDeployer = new MainDeployer();
        mainDeployer_ = address(mainDeployer);
    }

    function deployBorrower() public {

        TitleFab titlefab = new TitleFab();
        LightSwitchFab lightswitchfab = new LightSwitchFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        PrincipalFab principalFab = new PrincipalFab();
        CollectorFab collectorFab = new CollectorFab();
        ThresholdFab thresholdFab = new ThresholdFab();

        borrowerDeployer = new BorrowerDeployer(mainDeployer_, titlefab, lightswitchfab, shelffab, pileFab, principalFab, collectorFab, thresholdFab);

        borrowerDeployer.deployLightSwitch();
        borrowerDeployer.deployTitle("Tinlake Loan", "TLNT");
        borrowerDeployer.deployPile();
        borrowerDeployer.deployPrincipal();
        borrowerDeployer.deployShelf(currency_);

        borrowerDeployer.deployThreshold();
        borrowerDeployer.deployCollector();

        borrowerDeployer.deploy();

    }

    function deployLender() public {
        DistributorFab distributorFab = new DistributorFab();
        LenderDeployer lenderDeployer = new LenderDeployer(mainDeployer_,distributorFab );


        lenderDeployer.deployDistributor(currency_);
        lenderDeployer.deploy();
    }
}
