// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
import "ds-test/test.sol";

import "../../../test/mock/mock.sol";
import "tinlake-auth/auth.sol";

contract NAVFeedMock is Mock, Auth {
    constructor() {
        wards[msg.sender] = 1;
    }

    function latestNAV() public view returns (uint) {
        return values_return["latestNAV"];
    }

    function calcUpdateNAV() public returns (uint) {
        return call("calcUpdateNAV");
    }

    function currentNAV() public view returns (uint) {
        return values_return["currentNAV"];
    }
}
