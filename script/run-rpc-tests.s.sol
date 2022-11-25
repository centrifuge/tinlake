// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";

import {TinlakeRPCTests} from "./rpc-tests/rpc-tests.sol";

interface DependLike {
    function depend(bytes32, address) external;
}

contract RunRPCTests is Script, TinlakeRPCTests {
    function setUp() public {}

    function _isMakerLive() internal returns (bool) {
        return mgr.urn() != address(0) && clerk.activated();
    }

    function _deactivateClerk() internal {
        if (address(assessor.lending()) != address(0)) {
            console.log("PreRPC Test: remove clerk dependency from assessor");
            root.relyContract(address(assessor), address(this));
            assessor.depend("lending", address(0));
        }

        if (address(reserve.lending()) != address(0)) {
            console.log("PreRPC Test: remove clerk dependency from reserve");
            root.relyContract(address(reserve), address(this));
            reserve.depend("lending", address(0));
        }
    }

    function run() public {
        initRPC(vm.envAddress("ROOT_CONTRACT"));
        if (vm.envBool("MAKER_RPC_TESTS") == true) {
            console.log("Running: Maker RPC tests");
            if (_isMakerLive()) {
                runLoanCycleWithMaker();
            } else {
                revert("Maker is not live");
            }
        } else {
            // deactivate clerk to run without maker
            console.log("Running: Basic RPC tests");
            _deactivateClerk();
            runLoanCycleWithoutMaker();
        }
        console.log("RPC tests passed");
    }
}
