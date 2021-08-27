// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { PoolAdmin } from "./../admin/pool.sol";

contract PoolAdminFab {
    function newPoolAdmin() public returns (address) {
        PoolAdmin poolAdmin = new PoolAdmin();

        poolAdmin.relyWard(msg.sender);
        poolAdmin.denyWard(address(this));

        return address(poolAdmin);
    }
}
