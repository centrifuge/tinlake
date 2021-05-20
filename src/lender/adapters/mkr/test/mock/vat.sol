// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
import "ds-test/test.sol";

import "../../../../../test/mock/mock.sol";

contract VatMock is Mock {
    function urns(bytes32, address) external view returns (uint, uint) {
        return (values_return["ink"], values_uint["tab"]);
    }

    function setInk(uint amountDROP) external {
        values_return["ink"] = amountDROP;
    }


    function increaseTab(uint amountDAI) external {
        values_uint["tab"] = safeAdd(values_uint["tab"], amountDAI);
    }

    function decreaseTab(uint amountDAI) external {
        values_uint["tab"] = safeSub(values_uint["tab"], amountDAI);
    }

    function ilks(bytes32) external view returns(uint, uint, uint, uint, uint)  {
        return(0, values_return["stabilityFeeIdx"], 0, 0, 0);
    }
}
