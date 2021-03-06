// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "tinlake-auth/auth.sol";

import "../../../test/mock/mock.sol";

contract ClerkMock is Mock, Auth {
    
    constructor() {
        wards[msg.sender] = 1;
    }

    function remainingCredit() external view returns (uint) {
        return values_return["remainingCredit"];
    }
    function juniorStake() external view returns (uint) {
        return values_return["juniorStake"];
    }
    function remainingOvercollCredit() external view returns (uint) {
        return values_return["remainingOvercollCredit"];
    }

    function debt() external view returns(uint) {
        return values_return["debt"];
    }

    function stabilityFee() external view returns(uint) {
        return values_return["stabilityFee"];
    }

    function activated() public view returns(bool) {
        return values_bool_return["activated"];
    }

    function calcOvercollAmount(uint) external view returns (uint) {
        return values_return["calcOvercollAmount"];
    }

    function raise(uint256 amount) public auth {
        calls["raise"]++;
        values_uint["clerk_raise_amount"] = amount;
    }

    function sink(uint256 amount) public auth {
        calls["sink"]++;
        values_uint["clerk_sink_amount"] = amount;
    }

    function heal() public auth {
        calls["heal"]++;
    }

}

