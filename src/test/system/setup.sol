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
  NFTFeedFab,
  NAVFeedFab,
  CollectorFab,
  BorrowerDeployer
} from "../../borrower/deployer.sol";


import { EpochCoordinator } from "../../lender/coordinator.sol";
import { Reserve } from "../../lender/reserve.sol";
import { Tranche } from "../../lender/tranche.sol";
import { Operator } from "../../lender/operator.sol";
import { Assessor } from "../../lender/assessor.sol";
import { RestrictedToken } from "../../lender/token/restricted.sol";
import { Memberlist } from "../../lender/token/memberlist.sol";


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
import { NAVFeed } from "../../borrower/feed/navfeed.sol";

import { TestRoot } from "./root.sol";

import "../simple/token.sol";
import "../simple/distributor.sol";
import "tinlake-erc20/erc20.sol";
import { PushRegistry } from "tinlake-registry/registry.sol";
import { TokenLike, NFTFeedLike } from "./interfaces.sol";

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
    NAVFeed      nftFeed;
    Collector    collector;


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
    RestrictedToken seniorToken;
    RestrictedToken juniorToken;
    Memberlist seniorMemberlist;
    Memberlist juniorMemberlist;


    // Deployers
    BorrowerDeployer public borrowerDeployer;
    LenderDeployer public  lenderDeployer_;

    // todo will be removed
    LenderDeployer public  lenderDeployer;

    TestRoot root;
    address  root_;

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function deployContracts(bytes32 feed_) public {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);

        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);

        root = new TestRoot(address(this));
        root_ = address(root);

        // only admin is main deployer
        deployBorrower("nav");
        // only admin is main deployer

        prepareDeployLender(root_);
        deployLender();

        lenderDeployer = lenderDeployer_;

        root.prepare(address(lenderDeployer), address(borrowerDeployer), address(this));
        root.deploy();

    }

    function deployBorrower(bytes32 feed_) private {
        TitleFab titlefab = new TitleFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        CollectorFab collectorFab = new CollectorFab();
        address nftFeedFab_;

        if (feed_ == "default") {
            nftFeedFab_ = address(new NFTFeedFab());
        } else if (feed_ == "nav") {
            nftFeedFab_ = address(new NAVFeedFab());
        }

        uint discountRate = uint(1000000342100000000000000000);

        borrowerDeployer = new BorrowerDeployer(root_, titlefab, shelffab, pileFab, collectorFab, nftFeedFab_, currency_, "Tinlake Loan Token", "TLNT", discountRate);

        borrowerDeployer.deployTitle();
        borrowerDeployer.deployPile();
        borrowerDeployer.deployFeed();
        borrowerDeployer.deployShelf();
        borrowerDeployer.deployCollector();
        borrowerDeployer.deploy();

        shelf = Shelf(borrowerDeployer.shelf());
        pile = Pile(borrowerDeployer.pile());
        title = Title(borrowerDeployer.title());
        collector = Collector(borrowerDeployer.collector());
        nftFeed = NAVFeed(borrowerDeployer.feed());
    }

    function deployLenderMockBorrower(address root) public {
        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);

        prepareDeployLender(root);
        deployLender();
        
        // add root mock
        ShelfMock shelf = new ShelfMock();
        NAVFeedMock nav = new NAVFeedMock();
    
        assessor.depend("navFeed", address(nav));
        reserve.depend("shelf", address(shelf));
    }

    function prepareDeployLender(address root) public {

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
        lenderDeployer_ = new LenderDeployer(root, currency_, trancheFab, reserveFab, assessorFab, coordinatorFab, operatorFab,
            seniorTokenName, seniorTokenSymbol, juniorTokenName, juniorTokenSymbol);
    }

    function deployLender() public {
        // 2 % per day
        uint seniorInterestRate = uint(1000000229200000000000000000);
        uint maxReserve = uint(-1);
        uint maxSeniorRatio = 85 * 10 **25;
        uint minSeniorRatio = 75 * 10 **25;
        uint challengeTime = 1 hours;

        lenderDeployer_.init(minSeniorRatio, maxSeniorRatio, maxReserve, challengeTime, seniorInterestRate);

        lenderDeployer_.deployJunior();
        lenderDeployer_.deploySenior();
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
        seniorToken = RestrictedToken(lenderDeployer_.seniorToken());
        juniorToken = RestrictedToken(lenderDeployer_.juniorToken());
        juniorMemberlist = Memberlist(lenderDeployer_.juniorMemberlist());
        seniorMemberlist = Memberlist(lenderDeployer_.seniorMemberlist());
    }
}
