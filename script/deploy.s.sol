// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;

import {TinlakeRoot} from "src/root.sol";

import {TitleFab} from "src/borrower/fabs/title.sol";
import {ShelfFab} from "src/borrower/fabs/shelf.sol";
import {PileFab} from "src/borrower/fabs/pile.sol";
import {PrincipalNAVFeedFab} from "src/borrower/fabs/navfeed.principal.sol";
import {BorrowerDeployer} from "src/borrower/deployer.sol";

import {ReserveFab} from "src/lender/fabs/reserve.sol";
import {AssessorFab} from "src/lender/fabs/assessor.sol";
import {PoolAdminFab} from "src/lender/fabs/pooladmin.sol";
import {TrancheFab} from "src/lender/fabs/tranche.sol";
import {MemberlistFab} from "src/lender/fabs/memberlist.sol";
import {RestrictedTokenFab} from "src/lender/fabs/restrictedtoken.sol";
import {OperatorFab} from "src/lender/fabs/operator.sol";
import {CoordinatorFab} from "src/lender/fabs/coordinator.sol";
import {ClerkFab} from "src/lender/adapters/mkr/fabs/clerk.sol";
import {AdapterDeployer} from "src/lender/adapters/deployer.sol";
import {LenderDeployer} from "src/lender/deployer.sol";

import "forge-std/Script.sol";

contract TinlakeDeployScript is Script {
    address governance = 0x0A735602a357802f553113F5831FE2fbf2F0E2e0;
    address currency = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    address oracle = address(0);

    address memberAdmin = 0xaEcFA11fE9601c1B960661d7083A08A5df7c1947;
    address[] level1_admins;
    address level3_admin1 = 0x3018F3F7a1a919Fd9a1e0D8FEDbe9164B6DF04f6;

    uint256 discountRate = 1000000004439370877727042110;
    uint256 minSeniorRatio = 0;
    uint256 maxSeniorRatio = 900000000000000000000000000;
    uint256 maxReserve = 100000000000000000000000;
    uint256 challengeTime = 1800;
    uint256 seniorInterestRate = 1000000001585489599188229325;

    string seniorTokenName = "Goerli Test Pool 1 DROP";
    string seniorTokenSymbol = "GTP1DROP";
    string juniorTokenName = "Goerli Test Pool 1 TIN";
    string juniorTokenSymbol = "GTP1DROP";

    bool isMkr = true;
    address mkrMgrFab = 0xE5797dD56688f80B79C1FAC7D4441c60cCE95b09;

    mapping(string => address) contracts;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // TODO: use JSON parsing to read config file
        // json = cheats.readFile("config.json");
        // bytes memory data = cheats.parseJson(json);
        // Config memory config = abi.decode(data, (Config));

        // TODO: add caching based on bytecode
        // bytes memory bytecode = vm.getCode("src/borrower/fabs/title.sol:TitleFab");

        TinlakeRoot root = new TinlakeRoot(msg.sender, governance);

        address borrowerDeployer = deployBorrower(root);
        (address lenderDeployer, address adapterDeployer) = deployLender(root);

        root.prepare(lenderDeployer, borrowerDeployer, adapterDeployer, oracle, level1_admins, level3_admin1);
        root.deploy();

        printContracts(root);

        vm.stopBroadcast();
    }

    function deployBorrower(TinlakeRoot root) internal returns (address) {
        BorrowerDeployer borrowerDeployer =
        new BorrowerDeployer(address(root), address(new TitleFab()), address(new ShelfFab()), address(new PileFab()), address(new PrincipalNAVFeedFab()), currency, "Tinlake Loan Token", "TLNFT", discountRate);

        borrowerDeployer.deployTitle();
        borrowerDeployer.deployPile();
        borrowerDeployer.deployFeed();
        borrowerDeployer.deployShelf();
        borrowerDeployer.deploy();

        return address(borrowerDeployer);
    }

    function deployLender(TinlakeRoot root) internal returns (address, address) {
        address adapterDeployer = address(0);
        if (isMkr) {
            adapterDeployer = address(new AdapterDeployer(address(root), address(new ClerkFab()), mkrMgrFab));
        }

        LenderDeployer lenderDeployer =
        new LenderDeployer(address(root), currency, address(new TrancheFab()), address(new MemberlistFab()), address(new RestrictedTokenFab()), address(new ReserveFab()), address(new AssessorFab()), address(new CoordinatorFab()), address(new OperatorFab()), address(new PoolAdminFab()), memberAdmin, adapterDeployer);

        lenderDeployer.init(
            minSeniorRatio,
            maxSeniorRatio,
            maxReserve,
            challengeTime,
            seniorInterestRate,
            seniorTokenName,
            seniorTokenSymbol,
            juniorTokenName,
            juniorTokenSymbol
        );
        lenderDeployer.deployJunior();
        lenderDeployer.deploySenior();
        lenderDeployer.deployReserve();
        lenderDeployer.deployAssessor();
        lenderDeployer.deployPoolAdmin();
        lenderDeployer.deployCoordinator();
        lenderDeployer.deploy();

        // TODO: if (isMkr) deploy mgr

        return (address(lenderDeployer), address(adapterDeployer));
    }

    function printContracts(TinlakeRoot root) internal {
        console.log("ROOT_CONTRACT=%s", address(root));
        console.log("TINLAKE_CURRENCY=%s", currency);
        console.log("MEMBER_ADMIN=%s", memberAdmin);

        BorrowerDeployer borrowerDeployer = BorrowerDeployer(address(root.borrowerDeployer()));
        console.log("TITLE=%s", address(borrowerDeployer.title()));
        console.log("PILE=%s", address(borrowerDeployer.pile()));
        console.log("FEED=%s", address(borrowerDeployer.feed()));
        console.log("SHELF=%s", address(borrowerDeployer.shelf()));

        LenderDeployer lenderDeployer = LenderDeployer(address(root.lenderDeployer()));
        console.log("JUNIOR_TRANCHE=%s", address(lenderDeployer.juniorTranche()));
        console.log("JUNIOR_TOKEN=%s", address(lenderDeployer.juniorToken()));
        console.log("JUNIOR_OPERATOR=%s", address(lenderDeployer.juniorOperator()));
        console.log("JUNIOR_MEMBERLIST=%s", address(lenderDeployer.juniorMemberlist()));

        console.log("SENIOR_TRANCHE=%s", address(lenderDeployer.seniorTranche()));
        console.log("SENIOR_TOKEN=%s", address(lenderDeployer.seniorToken()));
        console.log("SENIOR_OPERATOR=%s", address(lenderDeployer.seniorOperator()));
        console.log("SENIOR_MEMBERLIST=%s", address(lenderDeployer.seniorMemberlist()));

        console.log("RESERVE=%s", address(lenderDeployer.reserve()));
        console.log("ASSESSOR=%s", address(lenderDeployer.assessor()));
        console.log("POOL_ADMIN=%s", address(lenderDeployer.poolAdmin()));
        console.log("COORDINATOR=%s", address(lenderDeployer.coordinator()));

        // console.log("CLERK=%s", address(lenderDeployer.clerk()));
    }
}
