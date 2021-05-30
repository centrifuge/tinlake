// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

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
import { PoolAdmin } from "../../lender/admin/pool.sol";
import { RestrictedToken } from "../../lender/token/restricted.sol";
import { Memberlist } from "../../lender/token/memberlist.sol";
import { Clerk } from "../../lender/adapters/mkr/clerk.sol";


import { TrancheFab } from "../../lender/fabs/tranche.sol";
import { RestrictedTokenFab } from "../../lender/fabs/restrictedtoken.sol";
import { MemberlistFab } from "../../lender/fabs/memberlist.sol";
import { AssessorFab } from "../../lender/fabs/assessor.sol";
import { PoolAdminFab } from "../../lender/fabs/pooladmin.sol";
import { ReserveFab } from "../../lender/fabs/reserve.sol";
import { CoordinatorFab } from "../../lender/fabs/coordinator.sol";
import { OperatorFab } from "../../lender/fabs/operator.sol";
import { LenderDeployer } from "../../lender/deployer.sol";

// MKR
import { MKRLenderDeployer } from "../../lender/adapters/mkr/deployer.sol";
import { ClerkFab } from "../../lender/adapters/mkr/fabs/clerk.sol";

import { Title } from "tinlake-title/title.sol";
import { Pile } from "../../borrower/pile.sol";
import { Shelf } from "../../borrower/shelf.sol";
import { Collector } from "../../borrower/collect/collector.sol";
import { NAVFeed } from "../../borrower/feed/navfeed.sol";

import { TestRoot } from "./root.sol";

import "../simple/token.sol";
import "tinlake-erc20/erc20.sol";

import { TokenLike, NFTFeedLike } from "./interfaces.sol";

import {SimpleMkr} from "./../simple/mkr.sol";


import "../../borrower/test/mock/shelf.sol";
import "../../lender/test/mock/navFeed.sol";
import "../../lender/adapters/mkr/test/mock/spotter.sol";
import "./config.sol";

// abstract contract
abstract contract LenderDeployerLike {
    address public root;
    address public currency;

    // contract addresses
    address             public assessor;
    address             public poolAdmin;
    address             public seniorTranche;
    address             public juniorTranche;
    address             public seniorOperator;
    address             public juniorOperator;
    address             public reserve;
    address             public coordinator;

    address             public seniorToken;
    address             public juniorToken;

    // token names
    string              public seniorName;
    string              public seniorSymbol;
    string              public juniorName;
    string              public juniorSymbol;
    // restricted token member list
    address             public seniorMemberlist;
    address             public juniorMemberlist;

    address             public deployer;

    function deployJunior() public virtual;
    function deploySenior() public virtual;
    function deployReserve() public virtual;
    function deployAssessor() public virtual;
    function deployPoolAdmin(address, address, address, address, address, address) public virtual;
    function deployCoordinator() public virtual;

    function deploy() public virtual;
    function deployMkr() public virtual;
}

abstract contract TestSetup is Config  {
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
    PoolAdmin poolAdmin;
    RestrictedToken seniorToken;
    RestrictedToken juniorToken;
    Memberlist seniorMemberlist;
    Memberlist juniorMemberlist;

    // Deployers
    BorrowerDeployer public borrowerDeployer;
    LenderDeployer public  lenderDeployer;

    //mkr adapter
    SimpleMkr mkr;
    MKRLenderDeployer public  mkrLenderDeployer;
    Clerk public clerk;

    address public lenderDeployerAddr;

    TestRoot root;
    address  root_;

    TinlakeConfig internal deploymentConfig;

    function issueNFT(address usr) public virtual returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }


    function deployContracts() public virtual {
        bool mkrAdapter = false;
        TinlakeConfig memory defaultConfig = defaultConfig();
        deployContracts(mkrAdapter, defaultConfig);
    }

    function deployContracts(bool mkrAdapter, TinlakeConfig memory config) public virtual {
        deployTestRoot();
        deployCollateralNFT();
        deployCurrency();
        deployBorrower(config);

        prepareDeployLender(root_, mkrAdapter);
        deployLender(mkrAdapter, config);

        root.prepare(lenderDeployerAddr, address(borrowerDeployer));
        root.deploy();
        deploymentConfig = config;
    }

    function deployTestRoot() public virtual {
        root = new TestRoot(address(this), address(this));
        root_ = address(root);
    }

    function deployCurrency() public virtual {
        currency = new SimpleToken("C", "Currency");
        currency_ = address(currency);
    }

    function deployCollateralNFT() public virtual {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);
    }

    function deployBorrower(TinlakeConfig memory config) internal {
        TitleFab titlefab = new TitleFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        CollectorFab collectorFab = new CollectorFab();
        address nftFeedFab_;
        nftFeedFab_ = address(new NAVFeedFab());

        borrowerDeployer = new BorrowerDeployer(root_, address(titlefab), address(shelffab), address(pileFab),
            address(collectorFab), nftFeedFab_, currency_, config.titleName, config.titleSymbol, config.discountRate);

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

    function deployLenderMockBorrower(address rootAddr) public virtual {
        currency = new SimpleToken("C", "Currency");
        currency_ = address(currency);

        prepareDeployLender(rootAddr, false);

        deployLender();

        // add root mock
        ShelfMock shelf_ = new ShelfMock();
        NAVFeedMock nav = new NAVFeedMock();

        assessor.depend("navFeed", address(nav));
        reserve.depend("shelf", address(shelf_));
    }

    function prepareMKRLenderDeployer(address rootAddr, address trancheFab, address memberlistFab, address restrictedTokenFab,
        address reserveFab, address coordinatorFab, address operatorFab, address poolAdminFab) public virtual {
        AssessorFab assessorFab = new AssessorFab();
        ClerkFab clerkFab = new ClerkFab();

        mkrLenderDeployer = new MKRLenderDeployer(rootAddr, currency_, address(trancheFab), address(memberlistFab),
            address(restrictedTokenFab), address(reserveFab), address(assessorFab), address(coordinatorFab),
            address(operatorFab), address(poolAdminFab), address(clerkFab), address(0));
        lenderDeployerAddr = address(mkrLenderDeployer);
        lenderDeployer = LenderDeployer(address(mkrLenderDeployer));
        return;

    }

    function prepareDeployLender(address rootAddr, bool mkrAdapter) public virtual {
        ReserveFab reserveFab = new ReserveFab();
        AssessorFab assessorFab = new AssessorFab();
        PoolAdminFab poolAdminFab = new PoolAdminFab();
        TrancheFab  trancheFab = new TrancheFab();
        MemberlistFab memberlistFab = new MemberlistFab();
        RestrictedTokenFab restrictedTokenFab = new RestrictedTokenFab();
        OperatorFab operatorFab = new OperatorFab();
        CoordinatorFab coordinatorFab = new CoordinatorFab();

        // deploy lender deployer for mkr adapter
        if(mkrAdapter) {
            prepareMKRLenderDeployer(rootAddr, address(trancheFab), address(memberlistFab), address(restrictedTokenFab),
                address(reserveFab), address(coordinatorFab),
                address(operatorFab), address(poolAdminFab));
            return;
        }

        // root is testcase
        lenderDeployer = new LenderDeployer(rootAddr, currency_, address(trancheFab),
            address(memberlistFab), address(restrictedTokenFab), address(reserveFab),
            address(assessorFab), address(coordinatorFab), address(operatorFab), address(poolAdminFab), address(0));
        lenderDeployerAddr = address(lenderDeployer);
    }

    function deployLender() public virtual {
        bool mkrAdapter = false;
        TinlakeConfig memory defaultConfig = defaultConfig();
        deployLender(mkrAdapter, defaultConfig);
        deploymentConfig = defaultConfig;
    }

    function _initMKR(TinlakeConfig memory config) public virtual {
        mkr = new SimpleMkr(config.mkrStabilityFee, config.mkrILK);
        address jug_ = address(mkr.jugMock());

        SpotterMock spotter = new SpotterMock();
        spotter.setReturn("mat", config.mkrMAT);

        mkrLenderDeployer.init(config.minSeniorRatio, config.maxSeniorRatio, config.maxReserve, config.challengeTime, config.seniorInterestRate, config.seniorTokenName,
            config.seniorTokenSymbol, config.juniorTokenName, config.juniorTokenSymbol);

        mkrLenderDeployer.initMKR(address(mkr), address(spotter), address(mkr), jug_);
    }

    function fetchContractAddr(LenderDeployerLike ld) internal {
        assessor = Assessor(ld.assessor());
        poolAdmin = PoolAdmin(ld.poolAdmin());
        reserve = Reserve(ld.reserve());
        coordinator = EpochCoordinator(ld.coordinator());
        seniorTranche = Tranche(ld.seniorTranche());
        juniorTranche = Tranche(ld.juniorTranche());
        juniorOperator = Operator(ld.juniorOperator());
        seniorOperator = Operator(ld.seniorOperator());
        seniorToken = RestrictedToken(ld.seniorToken());
        juniorToken = RestrictedToken(ld.juniorToken());
        juniorMemberlist = Memberlist(ld.juniorMemberlist());
        seniorMemberlist = Memberlist(ld.seniorMemberlist());
    }

    function deployLender(bool mkrAdapter, TinlakeConfig memory config) public virtual {
        LenderDeployerLike ld = LenderDeployerLike(lenderDeployerAddr);

        if (mkrAdapter) {
            _initMKR(config);
        } else {
            lenderDeployer.init(
                config.minSeniorRatio, config.maxSeniorRatio, config.maxReserve, config.challengeTime, config.seniorInterestRate,
                    config.seniorTokenName, config.seniorTokenSymbol, config.juniorTokenName, config.juniorTokenSymbol);
        }

        ld.deployJunior();
        ld.deploySenior();
        ld.deployReserve();
        ld.deployAssessor();
        ld.deployPoolAdmin(address(0), address(0), address(0), address(0), address(0), address(0));
        ld.deployCoordinator();

        if(mkrAdapter) {
            mkrLenderDeployer.deployClerk();
            clerk = Clerk(mkrLenderDeployer.clerk());
        }

        ld.deploy();
        fetchContractAddr(ld);
    }
}
