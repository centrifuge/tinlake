// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;
pragma abicoder v2;

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
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // TODO: add caching based on bytecode
        // bytes memory bytecode = vm.getCode("src/borrower/fabs/title.sol:TitleFab");

        TinlakeRoot root = new TinlakeRoot(msg.sender, vm.envAddress("GOVERNANCE"));

        address borrowerDeployer = deployBorrower(root);
        (address lenderDeployer, address adapterDeployer) = deployLender(root);

        root.prepare(
            lenderDeployer,
            borrowerDeployer,
            adapterDeployer,
            address(0),
            vm.envAddress("LEVEL1_ADMINS", ","),
            vm.envAddress("LEVEL3_ADMIN1")
        );
        root.deploy();

        printContracts(root);

        vm.stopBroadcast();
    }

    function deployBorrower(TinlakeRoot root) internal returns (address) {
        BorrowerDeployer borrowerDeployer =
        new BorrowerDeployer(address(root), address(new TitleFab()), address(new ShelfFab()), address(new PileFab()), address(new PrincipalNAVFeedFab()), vm.envAddress("TINLAKE_CURRENCY"), "Tinlake Loan Token", "TLNFT", vm.envUint("DISCOUNT_RATE"));

        borrowerDeployer.deployTitle();
        borrowerDeployer.deployPile();
        borrowerDeployer.deployFeed();
        borrowerDeployer.deployShelf();
        borrowerDeployer.deploy();

        return address(borrowerDeployer);
    }

    function deployLender(TinlakeRoot root) internal returns (address, address) {
        address adapterDeployer = address(0);
        if (vm.envBool("IS_MKR")) {
            adapterDeployer =
                address(new AdapterDeployer(address(root), address(new ClerkFab()), vm.envAddress("MKR_MGR_FAB")));
        }

        LenderDeployer lenderDeployer =
        new LenderDeployer(address(root), vm.envAddress("TINLAKE_CURRENCY"), address(new TrancheFab()), address(new MemberlistFab()), address(new RestrictedTokenFab()), address(new ReserveFab()), address(new AssessorFab()), address(new CoordinatorFab()), address(new OperatorFab()), address(new PoolAdminFab()), vm.envAddress("MEMBER_ADMIN"), adapterDeployer);

        lenderDeployer.init(
            vm.envUint("MIN_SENIOR_RATIO"),
            vm.envUint("MAX_SENIOR_RATIO"),
            vm.envUint("MAX_RESERVE"),
            vm.envUint("CHALLENGE_TIME"),
            vm.envUint("SENIOR_INTEREST_RATE"),
            vm.envString("SENIOR_TOKEN_NAME"),
            vm.envString("SENIOR_TOKEN_SYMBOL"),
            vm.envString("JUNIOR_TOKEN_NAME"),
            vm.envString("JUNIOR_TOKEN_SYMBOL")
        );
        lenderDeployer.deployJunior();
        lenderDeployer.deploySenior();
        lenderDeployer.deployReserve();
        lenderDeployer.deployAssessor();
        lenderDeployer.deployPoolAdmin();
        lenderDeployer.deployCoordinator();
        lenderDeployer.deploy();

        // TODO: if (vm.envBool("IS_MKR")) deploy mgr

        return (address(lenderDeployer), address(adapterDeployer));
    }

    function printContracts(TinlakeRoot root) internal {
        console.log("ROOT_CONTRACT=%s", address(root));
        console.log("TINLAKE_CURRENCY=%s", vm.envAddress("TINLAKE_CURRENCY"));
        console.log("MEMBER_ADMIN=%s", vm.envAddress("MEMBER_ADMIN"));

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
