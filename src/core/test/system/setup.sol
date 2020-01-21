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
import "./root_admin.sol";
import "../simple/token.sol";

import "tinlake-erc20/erc20.sol";

contract TestSetup is DSTest{
    Title public collateralNFT;
    address      public collateralNFT_;
    SimpleToken  public currency;
    address      public currency_;

    // Core contracts
    Shelf shelf;
    Pile pile;
    Title title;
    Principal ceiling;
    // CollectorLike collector;
    // ThresholdLike threshold;
    // PricePoolLike pricePool;
    // LightSwitchLike lightswitch;

    // Deployers
    BorrowerDeployer public borrowerDeployer;
    LenderDeployer public lenderDeployer;

    TestRootAdmin rootAdmin;
    address rootAdmin_;

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        uint tokenId = collateralNFT.issue(usr);
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function deployContracts() public {
        baseSetup();
        // only admin is main deployer
        deployBorrower();
        // only admin is main deployer
        deployDefaultLender();

        rootAdmin.file("borrower", address(borrowerDeployer));
        rootAdmin.file("lender", address(lenderDeployer));

        rootAdmin.completeDeployment();
    }

    function baseSetup() private {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);

        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);

        rootAdmin = new TestRootAdmin();
        rootAdmin_ = address(rootAdmin);
    }

    function deployBorrower() private {
        TitleFab titlefab = new TitleFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        PrincipalFab principalFab = new PrincipalFab();
        CollectorFab collectorFab = new CollectorFab();
        ThresholdFab thresholdFab = new ThresholdFab();
        PricePoolFab pricePoolFab = new PricePoolFab();

        borrowerDeployer = new BorrowerDeployer(rootAdmin_, titlefab, shelffab, pileFab, principalFab, collectorFab, thresholdFab, pricePoolFab);

        borrowerDeployer.deployTitle("Tinlake Loan", "TLNT");
        borrowerDeployer.deployPile();
        borrowerDeployer.deployPrincipal();
        borrowerDeployer.deployShelf(currency_);

        borrowerDeployer.deployThreshold();
        borrowerDeployer.deployCollector();
        borrowerDeployer.deployPricePool();

        borrowerDeployer.deploy();

        shelf = borrowerDeployer.shelf();
        pile = borrowerDeployer.pile();
        ceiling = borrowerDeployer.principal();
        title = borrowerDeployer.title();
        // collector = borrowerDeployer.collector();
        // threshold = borrowerDeployer.threshold();
        // pricePool = borrowerDeployer.pricePool();
        // lightswitch = borrowerDeployer.lightswitch();

    }

    function deployDefaultLender() private {
        lenderDeployer = new LenderDeployer(rootAdmin_, currency_, address(new TrancheFab()), address(new AssessorFab()),
            address(new WhitelistFab()), address(new SwitchableDistributorFab()));

        lenderDeployer.deployJuniorTranche("JUN", "Junior Tranche Token");

        lenderDeployer.deployAssessor();

        lenderDeployer.deployDistributor();

        lenderDeployer.deployJuniorOperator();
        lenderDeployer.deploy();
    }
}
