// Copyright (C) 2020 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.15 <0.6.0;
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

    function assertEq(uint a, uint b, bytes32 msg)  public {
        if(a != b) {
            emit log_named_bytes32(msg, "SystemTest - Assert Equal Failed");
        }
        assertEq(a, b);
    }

    // assert equal two variables with a wei tolerance
    function assertEqTol(uint actual, uint expected, bytes32 msg) public {
        uint diff;
        if(actual > expected) {
            diff = safeSub(actual, expected);
        } else {
            diff = safeSub(expected, actual);
        }
        if (diff > TOLERANCE) {
            emit log_named_bytes32(msg, "SystemTest - Assert Equal Failed");
            emit log_named_uint("Expected", expected);
            emit log_named_uint("Actual  ", actual);
            emit log_named_uint("Diff    ", diff);

        }
        assertTrue(diff <= TOLERANCE);
    }
}
