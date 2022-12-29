// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "./mock.sol";

contract RootMock is Mock {
    function borrowerDeployer() public view returns (address) {
        return values_address_return["borrowerDeployer"];
    }
}
