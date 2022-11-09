// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";

contract AssessorMock is Mock {
    function reBalance() public {
        calls["reBalance"]++;
    }
}
