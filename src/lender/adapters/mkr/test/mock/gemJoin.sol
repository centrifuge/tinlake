// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
import "ds-test/test.sol";

import "../../../../../test/mock/mock.sol";

contract GemJoin is Mock {
    function ilk() external view returns(bytes32){
        return values_bytes32_return["ilk"];
    }
}


