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

contract DeployScript is Script {
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
            vm.envAddress("ORACLE"),
            vm.envAddress("LEVEL1_ADMINS", ","),
            vm.envAddress("LEVEL3_ADMIN1")
        );
        root.deploy();

        console.log("ROOT_CONTRACT: %s", address(root));

        vm.stopBroadcast();
    }

    function deployBorrower(TinlakeRoot root) internal returns (address) {
        address feedFab = address(0);
        if (keccak256(abi.encodePacked(vm.envString("NAV_IMPLEMENTATION"))) == keccak256("PV")) {
            feedFab = getOrDeployFab("navfeedPV.sol:NAVFeedPVFab");
        } else if (keccak256(abi.encodePacked(vm.envString("NAV_IMPLEMENTATION"))) == keccak256("creditline")) {
            feedFab = getOrDeployFab("navfeed.creditline.sol:CreditlineNAVFeedFab");
        } else {
            feedFab = getOrDeployFab("navfeed.principal.sol:PrincipalNAVFeedFab");
        }

        BorrowerDeployer borrowerDeployer =
        new BorrowerDeployer(address(root), getOrDeployFab("title.sol:TitleFab"), getOrDeployFab("shelf.sol:ShelfFab"), getOrDeployFab("pile.sol:PileFab"), feedFab, vm.envAddress("TINLAKE_CURRENCY"), "Tinlake Loan Token", "TLNFT", vm.envUint("DISCOUNT_RATE"));

        borrowerDeployer.deployTitle();
        borrowerDeployer.deployPile();
        borrowerDeployer.deployFeed();
        borrowerDeployer.deployShelf();

        bool fileDiscountRateAndInitNAVFeed =
            keccak256(abi.encodePacked(vm.envString("NAV_IMPLEMENTATION"))) != keccak256("PV");
        borrowerDeployer.deploy(fileDiscountRateAndInitNAVFeed, fileDiscountRateAndInitNAVFeed);

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

        // Taken from https://github.com/0age/metamorphic/blob/master/contracts/ImmutableCreate2Factory.sol#L153
        address deploymentAddress = address(
            uint160( // downcast to match the address type.
                uint256( // convert to uint to truncate upper digits.
                    keccak256( // compute the CREATE2 hash using 4 inputs.
                        abi.encodePacked( // pack all inputs to the hash together.
                            hex"ff", // start with 0xff to distinguish from RLP.
                            address(factory), // this contract will be the caller.
                            salt, // pass in the supplied salt value.
                            keccak256( // pass in the hash of initialization code.
                            abi.encodePacked(initCode))
                        )
                    )
                )
            )
        );

        if (factory.hasBeenDeployed(deploymentAddress)) {
            return deploymentAddress;
        } else {
            return factory.safeCreate2(salt, initCode);
        }
    }
}
