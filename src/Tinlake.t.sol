pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./Tinlake.sol";

contract TinlakeTest is DSTest {
    Tinlake tinlake;

    function setUp() public {
        tinlake = new Tinlake();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
