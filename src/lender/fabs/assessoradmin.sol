// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { AssessorAdmin } from "./../admin/assessor.sol";

contract AssessorAdminFab {
    function newAssessorAdmin() public returns (address) {
        AssessorAdmin assessorAdmin = new AssessorAdmin();

        assessorAdmin.rely(msg.sender);
        assessorAdmin.deny(address(this));

        return address(assessorAdmin);
    }
}
