// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import "ds-test/test.sol";
import "tinlake-math/math.sol";

contract Assertions is DSTest, Math {
    uint TWO_DECIMAL_PRECISION = 10**16;
    uint FIXED27_TWO_DECIMAL_PRECISION = 10**25;
    uint FIXED27_TEN_DECIMAL_PRECISION = 10**17;

    // 2 wei default tolerance
    uint TOLERANCE= 2;

    // assertEq with precision tolerance
    function assertEq(uint a, uint b, uint precision)  public {
        assertEq(a/precision, b/precision);
    }

    // assert equal two variables with a wei tolerance
    function assertEqTol(uint actual, uint expected, bytes32 msg_) public {
        uint diff;
        if(actual > expected) {
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
