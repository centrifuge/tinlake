// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { Assessor } from "./../assessor.sol";

interface AssessorFabLike {
    function newAssessor() external returns (address);
}

contract AssessorFab {
    function newAssessor() public returns (address) {
        Assessor assessor = new Assessor();
        assessor.rely(msg.sender);
        assessor.deny(address(this));
        return address(assessor);
    }
}
