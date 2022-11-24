// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "forge-std/Test.sol";
import "../../lib/tinlake-math/src/math.sol";

contract Assertions is Test, Math {
    uint256 TWO_DECIMAL_PRECISION = 10 ** 16;
    uint256 FIXED27_TWO_DECIMAL_PRECISION = 10 ** 25;
    uint256 FIXED27_TEN_DECIMAL_PRECISION = 10 ** 17;

    // 2 wei default tolerance
    uint256 TOLERANCE = 2;

    // assertEq with precision tolerance
    function assertEq(uint256 a, uint256 b, uint256 precision) public {
        assertEq(a / precision, b / precision);
    }

    // assert equal two variables with a wei tolerance
    function assertEqTol(uint256 actual, uint256 expected, bytes32 msg_) public {
        uint256 diff;
        if (actual > expected) {
            diff = safeSub(actual, expected);
        } else {
            diff = safeSub(expected, actual);
        }
        if (diff > TOLERANCE) {
            emit log_named_bytes32(string(abi.encodePacked(msg_)), "SystemTest - Assert Equal Failed");
            emit log_named_uint("Expected", expected);
            emit log_named_uint("Actual  ", actual);
            emit log_named_uint("Diff    ", diff);
        }
        assertTrue(diff <= TOLERANCE);
    }
}