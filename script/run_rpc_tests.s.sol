// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";

import {TinlakeRPCTests} from "./rpc-tests/rpc-tests.sol";

contract RunRPCTests is Script, TinlakeRPCTests {
    function setUp() public {}

    function run() public {
        initRPC(vm.envAddress("ROOT_CONTRACT"));
        console.log("2");

        if (vm.envBool("MAKER_RPC_TESTS") == true) {
            runLoanCycleWithMaker();
        } else {
            runLoanCycleWithoutMaker();
        }
    }
}
