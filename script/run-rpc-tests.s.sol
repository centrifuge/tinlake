// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";

import {TinlakeRPCTests} from "./rpc-tests/rpc-tests.sol";

interface DSPauseProxy {
    function exec(address spell, bytes memory sig) external;
    function owner() external returns (address);
}

interface Spell {
    function action() external returns (address);
}

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

    function _executeMKRSpell() internal {
        // Maker has a concept called office hours
        // the spell can only be executed between 14:00 and 21:00 UTC during the week
        // fake office hours to Tue Dec 13 2022 14:39:41 GMT+0000
        vm.warp(1670942381);
        // DS Pause Proxy on Mainnet: 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB
        // executes the action contract of the spell
        DSPauseProxy dsPauseProxy = DSPauseProxy(vm.envAddress("MKR_PAUSE_PROXY"));

        // prank to be able to execute the spell
        vm.startPrank(dsPauseProxy.owner());
        dsPauseProxy.exec(Spell(vm.envAddress("SPELL")).action(), abi.encodeWithSignature("execute()"));
        vm.stopPrank();
    }

    function run() public {
        initRPC(vm.envAddress("ROOT_CONTRACT"));
        if (vm.envBool("MAKER_RPC_TESTS") == true) {
            console.log("Running: Maker RPC tests");
            if (vm.envAddress("SPELL") != address(0)) {
                _executeMKRSpell();
            }
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
