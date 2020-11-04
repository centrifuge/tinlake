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

import { TitleFab } from "../../borrower/fabs/title.sol";
import { ShelfFab } from "../../borrower/fabs/shelf.sol";
import { PileFab } from "../../borrower/fabs/pile.sol";
import { NFTFeedFab } from "../../borrower/fabs/nftfeed.sol";
import { NAVFeedFab } from "../../borrower/fabs/navfeed.sol";
import { CollectorFab } from "../../borrower/fabs/collector.sol";
import { BorrowerDeployer } from "../../borrower/deployer.sol";


import { EpochCoordinator } from "../../lender/coordinator.sol";
import { Reserve } from "../../lender/reserve.sol";
import { Tranche } from "../../lender/tranche.sol";
import { Operator } from "../../lender/operator.sol";
import { Assessor } from "../../lender/assessor.sol";
import { AssessorAdmin } from "../../lender/admin/assessor.sol";
import { RestrictedToken } from "../../lender/token/restricted.sol";
import { Memberlist } from "../../lender/token/memberlist.sol";


import { TrancheFab } from "../../lender/fabs/tranche.sol";
import { RestrictedTokenFab } from "../../lender/fabs/restrictedtoken.sol";
import { MemberlistFab } from "../../lender/fabs/memberlist.sol";
import { AssessorFab } from "../../lender/fabs/assessor.sol";
import { AssessorAdminFab } from "../../lender/fabs/assessoradmin.sol";
import { ReserveFab } from "../../lender/fabs/reserve.sol";
import { CoordinatorFab } from "../../lender/fabs/coordinator.sol";
import { OperatorFab } from "../../lender/fabs/operator.sol";
import { LenderDeployer } from "../../lender/deployer.sol";

import { Title } from "tinlake-title/title.sol";
import { Pile } from "../../borrower/pile.sol";
import { Shelf } from "../../borrower/shelf.sol";
import { Collector } from "../../borrower/collect/collector.sol";
import { NAVFeed } from "../../borrower/feed/navfeed.sol";

import { TestRoot } from "./root.sol";

import "../simple/token.sol";
import "../simple/distributor.sol";
import "tinlake-erc20/erc20.sol";

import { TokenLike, NFTFeedLike } from "./interfaces.sol";


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
    Reserve reserve;
    EpochCoordinator coordinator;
    Tranche seniorTranche;
    Tranche juniorTranche;
    Operator juniorOperator;
    Operator seniorOperator;
    Assessor assessor;
    AssessorAdmin assessorAdmin;
    RestrictedToken seniorToken;
    RestrictedToken juniorToken;
    Memberlist seniorMemberlist;
    Memberlist juniorMemberlist;


    // Deployers
    BorrowerDeployer public borrowerDeployer;
    LenderDeployer public  lenderDeployer;

    TestRoot root;
    address  root_;

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function deployContracts() public {
        deployTestRoot();
        deployCollateralNFT();
        deployCurrency();
        deployBorrower();

        prepareDeployLender(root_);
        deployLender();

        root.prepare(address(lenderDeployer), address(borrowerDeployer), address(this));
        root.deploy();
    }

    function deployTestRoot() public {
        root = new TestRoot(address(this));
        root_ = address(root);
    }

    function deployCurrency() public {
        currency = new SimpleToken("C", "Currency");
        currency_ = address(currency);
    }

    function deployCollateralNFT() public {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);
    }

    function deployBorrower() private {
        TitleFab titlefab = new TitleFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        CollectorFab collectorFab = new CollectorFab();
        address nftFeedFab_;
        nftFeedFab_ = address(new NAVFeedFab());

        uint discountRate = uint(1000000342100000000000000000);

        borrowerDeployer = new BorrowerDeployer(root_, address(titlefab), address(shelffab), address(pileFab), address(collectorFab), nftFeedFab_, currency_, "Tinlake Loan Token", "TLNT", discountRate);

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

    function deployLenderMockBorrower(address rootAddr) public {
        currency = new SimpleToken("C", "Currency");
        currency_ = address(currency);

        prepareDeployLender(rootAddr);
        deployLender();

        // add root mock
        ShelfMock shelf_ = new ShelfMock();
        NAVFeedMock nav = new NAVFeedMock();

        assessor.depend("navFeed", address(nav));
        reserve.depend("shelf", address(shelf_));
    }

    function prepareDeployLender(address rootAddr) public {

        ReserveFab reserveFab = new ReserveFab();
        AssessorFab assessorFab = new AssessorFab();
        AssessorAdminFab assessorAdminFab = new AssessorAdminFab();
        TrancheFab  trancheFab = new TrancheFab();
        MemberlistFab memberlistFab = new MemberlistFab();
        RestrictedTokenFab restrictedTokenFab = new RestrictedTokenFab();
        OperatorFab operatorFab = new OperatorFab();
        CoordinatorFab coordinatorFab = new CoordinatorFab(); 

        // root is testcase
        lenderDeployer = new LenderDeployer(rootAddr, currency_, address(trancheFab), address(memberlistFab), address(restrictedTokenFab), address(reserveFab), address(assessorFab), address(coordinatorFab), address(operatorFab), address(assessorAdminFab));
    }

    function deployLender() public {
        // 2 % per day
        uint seniorInterestRate = uint(1000000229200000000000000000);
        uint maxReserve = uint(-1);
        uint maxSeniorRatio = 85 * 10 **25;
        uint minSeniorRatio = 75 * 10 **25;
        uint challengeTime = 1 hours;

        string memory seniorTokenName = "DROP Token";
        string memory seniorTokenSymbol = "DROP";
        string memory juniorTokenName = "TIN Token";
        string memory juniorTokenSymbol = "TIN";

        lenderDeployer.init(minSeniorRatio, maxSeniorRatio, maxReserve, challengeTime, seniorInterestRate, seniorTokenName, seniorTokenSymbol, juniorTokenName, juniorTokenSymbol);

        lenderDeployer.deployJunior();
        lenderDeployer.deploySenior();
        lenderDeployer.deployReserve();
        lenderDeployer.deployAssessor();
        lenderDeployer.deployAssessorAdmin();
        lenderDeployer.deployCoordinator();

        lenderDeployer.deploy();

        assessor = Assessor(lenderDeployer.assessor());
        assessorAdmin = AssessorAdmin(lenderDeployer.assessorAdmin());
        reserve = Reserve(lenderDeployer.reserve());
        coordinator = EpochCoordinator(lenderDeployer.coordinator());
        seniorTranche = Tranche(lenderDeployer.seniorTranche());
        juniorTranche = Tranche(lenderDeployer.juniorTranche());
        juniorOperator = Operator(lenderDeployer.juniorOperator());
        seniorOperator = Operator(lenderDeployer.seniorOperator());
        seniorToken = RestrictedToken(lenderDeployer.seniorToken());
        juniorToken = RestrictedToken(lenderDeployer.juniorToken());
        juniorMemberlist = Memberlist(lenderDeployer.juniorMemberlist());
        seniorMemberlist = Memberlist(lenderDeployer.seniorMemberlist());
    }
}
