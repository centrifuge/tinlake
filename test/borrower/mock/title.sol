// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";

contract TitleMock is Mock {
    function ownerOf(uint256) public view returns (address) {
        return values_address_return["ownerOf"];
    }

    function issue(address usr) public returns (uint256) {
        values_address["issue_usr"] = usr;
        return call("issue");
    }

    function close(uint256 loan) public {
        values_uint["close_loan"] = loan;
        calls["close"]++;
    }

    function count() public view returns (uint256) {
        return values_return["count"];
    }
}
