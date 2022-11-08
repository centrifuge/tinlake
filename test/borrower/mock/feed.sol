// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";

import "../../../test/mock/mock.sol";
import "tinlake-auth/auth.sol";

contract NAVFeedMock is Mock, Auth {
    constructor() {
        wards[msg.sender] = 1;
    }

    function pile() public view returns (address) {
        return values_address_return["pile"];
    }

    function shelf() public view returns (address) {
        return values_address_return["shelf"];
    }

    function maturityDate(bytes32 nft_) public view returns (uint256) {
        return values_return["maturityDate"];
    }

    function nftID(uint256 loan) public returns (bytes32) {
        return values_bytes32_return["nftID"];
    }
}
