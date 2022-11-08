// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";

import "test/mock/mock.sol";

contract Urn is Mock {
    function gemJoin() external view returns (address) {
        return values_address_return["gemJoin"];
    }
}
