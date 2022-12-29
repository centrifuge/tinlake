// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";

import {TinlakeRPCTests} from "./rpc-tests/rpc-tests.sol";

contract RunRPCTests is Script, TinlakeRPCTests {
    function setUp() public {}

    function _isMakerLive() internal returns (bool) {
        return mgr.urn() != address(0) && clerk.activated();
    }

    function _setClerk(address clerkAddr) internal {
        root.relyContract(address(assessor), address(this));
        root.relyContract(address(reserve), address(this));
        console.log("depend clerk in reserve and assessor:", clerkAddr);
        assessor.depend("lending", address(clerkAddr));
        reserve.depend("lending", address(clerk));
    }

    function _deactivateClerk() internal {
        if (address(assessor.lending()) != address(0) || address(reserve.lending()) != address(0)) {
            _setClerk(address(0));
        }
    }

    function run() public {
        initRPC(vm.envAddress("ROOT_CONTRACT"));
        if (vm.envBool("MAKER_RPC_TESTS") == true) {
            console.log("Running: Maker RPC tests");
            if (_isMakerLive()) {
                _setClerk(address(clerk));
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
