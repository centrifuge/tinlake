// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";

import "test/mock/mock.sol";

contract VatMock is Mock {
    function urns(bytes32, address) external view returns (uint256, uint256) {
        return (values_return["ink"], values_uint["tab"]);
    }

    function setInk(uint256 amountDROP) external {
        values_return["ink"] = amountDROP;
    }

    function increaseTab(uint256 amountDAI) external {
        values_uint["tab"] = safeAdd(values_uint["tab"], amountDAI);
    }

    function decreaseTab(uint256 amountDAI) external {
        values_uint["tab"] = safeSub(values_uint["tab"], amountDAI);
    }

    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256) {
        return (0, values_return["stabilityFeeIdx"], 0, 0, 0);
    }
}
