// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";

import {TinlakeRoot} from "src/root.sol";
import {BorrowerDeployer} from "src/borrower/deployer.sol";
import {AdapterDeployer} from "src/lender/adapters/deployer.sol";
import {LenderDeployer} from "src/lender/deployer.sol";

interface ImmutableCreate2Factory {
    function safeCreate2(bytes32 salt, bytes calldata initCode) external payable returns (address deploymentAddress);
    function findCreate2Address(bytes32 salt, bytes calldata initCode)
        external
        view
        returns (address deploymentAddress);
    function hasBeenDeployed(address deploymentAddress) external view returns (bool);
}

interface AnyContract {}

contract TinlakeDeployScript is Script {
    ImmutableCreate2Factory immutable factory = ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
    bytes32 salt = 0x00000000000000000000000000000000000000008b99e5a778edb02572010000;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

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
        new BorrowerDeployer(address(root), getOrDeployFab("title.sol:TitleFab"), getOrDeployFab("shelf.sol:ShelfFab"), getOrDeployFab("pile.sol:PileFab"), getOrDeployFab("navfeed.principal.sol:PrincipalNAVFeedFab"), vm.envAddress("TINLAKE_CURRENCY"), "Tinlake Loan Token", "TLNFT", vm.envUint("DISCOUNT_RATE"));

        borrowerDeployer.deployTitle();
        borrowerDeployer.deployPile();
        borrowerDeployer.deployFeed();
        borrowerDeployer.deployShelf();
        borrowerDeployer.deploy();

        return address(borrowerDeployer);
    }

    function deployLender(TinlakeRoot root) internal returns (address, address) {
        address adapterDeployer_ = address(0);
        if (vm.envBool("IS_MKR")) {
            adapterDeployer_ = address(
                new AdapterDeployer(address(root), getOrDeployFab("clerk.sol:ClerkFab"), vm.envAddress("MKR_MGR_FAB"))
            );
        }

        LenderDeployer lenderDeployer =
        new LenderDeployer(address(root), vm.envAddress("TINLAKE_CURRENCY"), getOrDeployFab("tranche.sol:TrancheFab"), getOrDeployFab("memberlist.sol:MemberlistFab"), getOrDeployFab("restrictedtoken.sol:RestrictedTokenFab"), getOrDeployFab("reserve.sol:ReserveFab"), getOrDeployFab("assessor.sol:AssessorFab"), getOrDeployFab("coordinator.sol:CoordinatorFab"), getOrDeployFab("operator.sol:OperatorFab"), getOrDeployFab("pooladmin.sol:PoolAdminFab"), vm.envAddress("MEMBER_ADMIN"), adapterDeployer_);

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

        if (vm.envBool("IS_MKR")) {
            AdapterDeployer adapterDeployer = AdapterDeployer(adapterDeployer_);
            adapterDeployer.deployClerk(address(lenderDeployer), vm.envBool("WIRE_CLERK"));
            // TODO: fix the next line
            adapterDeployer.deployMgr(
                vm.envAddress("MKR_DAI"),
                vm.envAddress("MKR_DAI_JOIN"),
                vm.envAddress("MKR_END"),
                vm.envAddress("MKR_VAT"),
                vm.envAddress("MKR_VOW"),
                vm.envAddress("MKR_LIQ"),
                vm.envAddress("MKR_SPOTTER"),
                vm.envAddress("MKR_JUG"),
                vm.envUint("MKR_MAT_BUFFER")
            );
        }

        return (address(lenderDeployer), adapterDeployer_);
    }

    function getOrDeployFab(string memory contractPath) internal returns (address) {
        bytes memory initCode = vm.getCode(contractPath);
        address deploymentAddress = factory.findCreate2Address(salt, initCode);

        if (factory.hasBeenDeployed(deploymentAddress)) {
            return deploymentAddress;
        } else {
            return factory.safeCreate2(salt, initCode);
        }
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

        AdapterDeployer adapterDeployer = AdapterDeployer(address(root.adapterDeployer()));
        console.log("CLERK=%s", address(adapterDeployer.clerk()));
        console.log("MAKER_MGR=%s", address(adapterDeployer.mgr()));
        console.log("MKR_VAT=%s", vm.envAddress("MKR_VAT"));
        console.log("MKR_JUG=%s", vm.envAddress("MKR_JUG"));
    }
}
