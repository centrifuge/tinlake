// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
import "forge-std/Test.sol";

import "../../../test/mock/mock.sol";

contract PoolMock is Mock {
    function totalValue() public view returns (uint) {
        return values_return["totalValue"];
    }
}
