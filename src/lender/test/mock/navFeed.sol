// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
import "ds-test/test.sol";

import "../../../test/mock/mock.sol";

contract NAVFeedMock is Mock {
    function approximatedNAV() public view returns (uint) {
        return values_return["approximatedNAV"];
    }

    function calcUpdateNAV() public returns (uint) {
        return call("calcUpdateNAV");
    }

    function currentNAV() public view returns (uint) {
        return values_return["currentNAV"];
    }
}
