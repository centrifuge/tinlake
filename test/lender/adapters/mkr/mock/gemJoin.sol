// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import "forge-std/Test.sol";

import "test/mock/mock.sol";

contract GemJoin is Mock {
    function ilk() external view returns(bytes32){
        return values_bytes32_return["ilk"];
    }
}


