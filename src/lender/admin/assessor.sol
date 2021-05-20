// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";

interface AssessorLike {
     function file(bytes32 name, uint value) external;
}

// Wrapper contract for permission restriction on the assessor.
// This contract ensures that only the maxReserve size of the pool can be set
contract AssessorAdmin is Auth {
    AssessorLike  public assessor;
    constructor() public {
        wards[msg.sender] = 1;
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else revert();
    }

    function setMaxReserve(uint value) public auth {
        assessor.file("maxReserve", value);
    }
}
