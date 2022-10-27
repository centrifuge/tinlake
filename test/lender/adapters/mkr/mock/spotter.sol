// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import "ds-test/test.sol";

import "../../../../../test/mock/mock.sol";

contract SpotterMock is Mock {
    function ilks(bytes32) external view returns(address, uint256) {
        return (values_address_return["pip"], values_return["mat"]);
    }
}
