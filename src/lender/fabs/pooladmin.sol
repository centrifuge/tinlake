// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { PoolAdmin } from "./../admin/pool.sol";

contract PoolAdminFab {
    function newPoolAdmin() public returns (address) {
        PoolAdmin poolAdmin = new PoolAdmin();

        poolAdmin.relyLevel3(msg.sender);
        poolAdmin.denyLevel3(address(this));

        return address(poolAdmin);
    }
}
