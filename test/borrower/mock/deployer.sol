// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../mock/mock.sol";

contract BorrowerDeployerMock is Mock {

    function shelf() public view returns (address) {
        return values_address_return["shelf"];
    }

    function pile() public view returns (address) {
        return values_address_return["pile"];
    }

    function feed() public view returns (address) {
        return values_address_return["feed"];
    }
}
