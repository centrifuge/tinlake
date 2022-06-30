// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import "ds-test/test.sol";

import "../../../test/mock/mock.sol";
import "tinlake-auth/auth.sol";

contract NAVFeedMock is Mock, Auth {
    constructor() {
        wards[msg.sender] = 1;
    }

    function maturityDate(bytes32 nft_)     public view returns(uint){ 
            return values_uint["load_maturityDate"];
        }

    function nftID(uint loan) public view returns (bytes32) {
        calls["nftID"]++;
        return values_bytes32["nftID"];
    }

    // function nftID(address registry, uint tokenId) public pure returns (bytes32) {
    //     return keccak256(abi.encodePacked(registry, tokenId));
    // }
}
