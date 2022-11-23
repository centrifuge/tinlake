// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../../../test/mock/mock.sol";

contract JugMock is Mock {
    bool interestUpdated = false;

    constructor() {
        values_return["base"] = 0;
        values_return["ilks_duty"] = 10 ** 27;
    }

    function ilks(bytes32) public view returns (uint256, uint256) {
        uint256 rho = block.timestamp;
        if (interestUpdated == false) {
            rho = values_return["ilks_rho"];
        }
        return (values_return["ilks_duty"], rho);
    }

    function drip(bytes32 ilk) public returns (uint256) {
        calls["drip"]++;
        values_bytes32["drip_ilk"] = ilk;
        return values_return["ilks_rates"];
    }

    function base() public view returns (uint256) {
        return values_return["base"];
    }

    function setInterestUpToDate(bool flag) public {
        interestUpdated = flag;
    }
}
