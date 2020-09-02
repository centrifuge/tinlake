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

pragma solidity >=0.5.15 <0.6.0;

import {
  TitleFab,
  ShelfFab,
  PileFab,
  PrincipalCeilingFab,
  CreditLineCeilingFab,
  CeilingFab,
  ThresholdFab,
  CollectorFab,
  PricePoolFab,
  BorrowerDeployer
} from "../../borrower/deployer.sol";


import { EpochCoordinator } from "../../lender/coordinator.sol";
import { Reserve } from "../../lender/reserve.sol";
import { Tranche } from "../../lender/tranche.sol";
import { Operator } from "../../lender/operator.sol";
import { Assessor } from "../../lender/assessor.sol";


import {
  TrancheFab,
  AssessorFab,
  ReserveFab,
  CoordinatorFab,
  OperatorFab,
  LenderDeployer,
  MockLenderDeployer
} from "../../lender/deployer.sol";

import { Title } from "tinlake-title/title.sol";
import { Pile } from "../../borrower/pile.sol";
import { Shelf } from "../../borrower/shelf.sol";
import { Collector } from "../../borrower/collect/collector.sol";
import { Principal } from "../../borrower/ceiling/principal.sol";
import { CreditLine } from "../../borrower/ceiling/creditline.sol";

import { TestRoot } from "./root.sol";

import "../simple/token.sol";
import "../simple/distributor.sol";

import "tinlake-erc20/erc20.sol";
import { PushRegistry } from "tinlake-registry/registry.sol";
import { TokenLike, CeilingLike } from "./interfaces.sol";

// todo legacy code
contract DistributorLike {
    function balance() public;
}

import "../../borrower/test/mock/shelf.sol";
import "../../lender/test/mock/navFeed.sol";

contract TestSetup {
    Title public collateralNFT;
    address      public collateralNFT_;
    SimpleToken  public currency;
    address      public currency_;

    // Borrower contracts
    Shelf        shelf;
    Pile         pile;
    Title        title;
    CeilingLike    ceiling;
    Collector    collector;
    PushRegistry threshold;


    // Lender contracts
    // mock
    DistributorLike  distributor;

    Reserve reserve;
    EpochCoordinator coordinator;
    Tranche seniorTranche;
    Tranche juniorTranche;
    Operator juniorOperator;
    Operator seniorOperator;
    Assessor assessor;



    // Deployers
    BorrowerDeployer public borrowerDeployer;
    LenderDeployer public  lenderDeployer_;

    // todo will be removed
    MockLenderDeployer public  lenderDeployer;


    TestRoot root;
    address  root_;

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function deployContracts(bytes32 ceiling_) public {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);

        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);

        root = new TestRoot(address(this));
        root_ = address(root);
        // only admin is main deployer
        deployBorrower(ceiling_);
        // only admin is main deployer

        deployMockLender();

        root.prepare(address(lenderDeployer), address(borrowerDeployer), address(this));
        root.deploy();
    }

    function deployBorrower(bytes32 ceiling_) private {
        TitleFab titlefab = new TitleFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        CollectorFab collectorFab = new CollectorFab();
        ThresholdFab thresholdFab = new ThresholdFab();
        PricePoolFab pricePoolFab = new PricePoolFab();
        address ceilingFab_;

        if (ceiling_ == "default") {
            ceilingFab_ = address(new PrincipalCeilingFab());
        } else if (ceiling_ == "creditline") {
            ceilingFab_ = address(new CreditLineCeilingFab());
        }

        borrowerDeployer = new BorrowerDeployer(root_, titlefab, shelffab, pileFab, ceilingFab_, collectorFab, thresholdFab, pricePoolFab, address(0), currency_, "Tinlake Loan Token", "TLNT");

        borrowerDeployer.deployTitle();
        borrowerDeployer.deployPile();
        borrowerDeployer.deployCeiling();
        borrowerDeployer.deployShelf();
        borrowerDeployer.deployThreshold();
        borrowerDeployer.deployCollector();
        borrowerDeployer.deployPricePool();
        borrowerDeployer.deploy();

        shelf = Shelf(borrowerDeployer.shelf());
        pile = Pile(borrowerDeployer.pile());
        ceiling = CeilingLike(borrowerDeployer.ceiling());

        title = Title(borrowerDeployer.title());
        collector = Collector(borrowerDeployer.collector());
        threshold = PushRegistry(borrowerDeployer.threshold());
    }

    function deployMockLender() public {
        lenderDeployer = new MockLenderDeployer(root_, currency_);
        distributor = DistributorLike(lenderDeployer.distributor_());

    }

    function deployLenderMockBorrower() public {
        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);
        prepareDeployLender();
        deployLender();

        // add root mock
        ShelfMock shelf = new ShelfMock();
        NAVFeedMock nav = new NAVFeedMock();

        assessor.depend("navFeed", address(nav));
        reserve.depend("shelf", address(shelf));
    }

    function prepareDeployLender() public {
//        CoordinatorFab  coordinatorFab = new CoordinatorFab();
        ReserveFab reserveFab = new ReserveFab();
        AssessorFab assessorFab = new AssessorFab();
        TrancheFab  trancheFab = new TrancheFab();
        OperatorFab operatorFab = new OperatorFab();
        CoordinatorFab coordinatorFab = new CoordinatorFab();

        string memory seniorTokenName = "DROP Token";
        string memory seniorTokenSymbol = "DROP";
        string memory juniorTokenName = "TIN Token";
        string memory juniorTokenSymbol = "TIN";

        // root is testcase
        lenderDeployer_ = new LenderDeployer(address(this), currency_, trancheFab, reserveFab, assessorFab, coordinatorFab, operatorFab,
            seniorTokenName, seniorTokenSymbol, juniorTokenName, juniorTokenSymbol);
    }

    function deployLender() public {
        // 12 % per year
        uint seniorInterestRate = uint(1000000003593629043335673583);
        uint maxReserve = 2000 ether;
        uint maxSeniorRatio = 85 * 10 **25;
        uint minSeniorRatio = 75 * 10 **25;
        uint challengeTime = 1 hours;

        lenderDeployer_.init(minSeniorRatio, maxSeniorRatio, maxReserve, challengeTime, seniorInterestRate);

        lenderDeployer_.deployTranches();
        lenderDeployer_.deployReserve();
        lenderDeployer_.deployAssessor();
        lenderDeployer_.deployCoordinator();
        lenderDeployer_.deploy();


        assessor = Assessor(lenderDeployer_.assessor());
        reserve = Reserve(lenderDeployer_.reserve());
        coordinator = EpochCoordinator(lenderDeployer_.coordinator());
        seniorTranche = Tranche(lenderDeployer_.seniorTranche());
        juniorTranche = Tranche(lenderDeployer_.juniorTranche());
        juniorOperator = Operator(lenderDeployer_.juniorOperator());
        seniorOperator = Operator(lenderDeployer_.seniorOperator());

    }
}
