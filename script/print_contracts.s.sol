// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";

import {TinlakeRoot} from "src/root.sol";
import {BorrowerDeployer} from "src/borrower/deployer.sol";
import {AdapterDeployer} from "src/lender/adapters/deployer.sol";
import {LenderDeployer} from "src/lender/deployer.sol";
import {Reserve} from "src/lender/reserve.sol";
import {Clerk} from "src/lender/adapters/mkr/clerk.sol";

interface MgrLike {
    function vat() external view returns (address);
}

contract PrintContractsScript is Script {
    function setUp() public {}

    function run() public {
        TinlakeRoot root = TinlakeRoot(vm.envAddress(("ROOT_CONTRACT")));

        BorrowerDeployer borrowerDeployer = BorrowerDeployer(address(root.borrowerDeployer()));
        LenderDeployer lenderDeployer = LenderDeployer(address(root.lenderDeployer()));

        console.log("\"ROOT_CONTRACT\": \"%s\",", address(root));
        console.log("\"TINLAKE_CURRENCY\": \"%s\",", address(Reserve(address(lenderDeployer.reserve())).currency()));

        console.log("\"TITLE\": \"%s\",", address(borrowerDeployer.title()));
        console.log("\"PILE\": \"%s\",", address(borrowerDeployer.pile()));
        console.log("\"FEED\": \"%s\",", address(borrowerDeployer.feed()));
        console.log("\"SHELF\": \"%s\",", address(borrowerDeployer.shelf()));

        console.log("\"JUNIOR_TRANCHE\": \"%s\",", address(lenderDeployer.juniorTranche()));
        console.log("\"JUNIOR_TOKEN\": \"%s\",", address(lenderDeployer.juniorToken()));
        console.log("\"JUNIOR_OPERATOR\": \"%s\",", address(lenderDeployer.juniorOperator()));
        console.log("\"JUNIOR_MEMBERLIST\": \"%s\",", address(lenderDeployer.juniorMemberlist()));

        console.log("\"SENIOR_TRANCHE\": \"%s\",", address(lenderDeployer.seniorTranche()));
        console.log("\"SENIOR_TOKEN\": \"%s\",", address(lenderDeployer.seniorToken()));
        console.log("\"SENIOR_OPERATOR\": \"%s\",", address(lenderDeployer.seniorOperator()));
        console.log("\"SENIOR_MEMBERLIST\": \"%s\",", address(lenderDeployer.seniorMemberlist()));

        console.log("\"RESERVE\": \"%s\",", address(lenderDeployer.reserve()));
        console.log("\"ASSESSOR\": \"%s\",", address(lenderDeployer.assessor()));
        console.log("\"POOL_ADMIN\": \"%s\",", address(lenderDeployer.poolAdmin()));
        console.log("\"COORDINATOR\": \"%s\",", address(lenderDeployer.coordinator()));

        if (address(root.adapterDeployer()) != address(0)) {
            AdapterDeployer adapterDeployer = AdapterDeployer(address(root.adapterDeployer()));
            console.log("\"CLERK\": \"%s\",", address(adapterDeployer.clerk()));
            console.log("\"MAKER_MGR\": \"%s\",", address(adapterDeployer.mgr()));
            console.log("\"MKR_VAT\": \"%s\",", MgrLike(adapterDeployer.mgr()).vat());
            console.log("\"MKR_JUG\": \"%s\",", address(Clerk(address(adapterDeployer.clerk())).jug()));
        }
    }
}
