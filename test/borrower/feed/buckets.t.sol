// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "src/borrower/feed/buckets.sol";


interface Hevm {
    function warp(uint256) external;
}

// Contract for testing the abstract Buckets contract
contract BucketList is Buckets, Math {
    function uniqueDayTimestamp(uint timestamp) public pure returns (uint) {
        return (1 days) * (timestamp/(1 days));
    }

    function add(uint timestamp, uint value) public {
        addBucket(uniqueDayTimestamp(timestamp), value);
    }

    function remove(uint timestamp) public {
        removeBucket(uniqueDayTimestamp(timestamp));
    }

    function calcSum() public view returns (uint) {
        uint currDate = firstBucket;
        uint sum = 0;

        if (currDate == 0) {
            //empty list
            return 0;
        }

        while(currDate != NullDate)
        {
            sum = safeAdd(sum, buckets[currDate].value);
            currDate = buckets[currDate].next;
        }
        return sum;
    }
}


contract BucketTest is DSTest, Math {
    Hevm hevm;
    BucketList buckets;

    function setUp() public {
        buckets = new BucketList();
    }

    function addBuckets() public {
        assertEq(buckets.firstBucket(), 0);
        assertEq(buckets.lastBucket(), 0);

        uint amount = 100 ether;

        // add first element
        buckets.add(block.timestamp + 5 days, amount);
        assertEq(buckets.calcSum(), 100 ether);
        assertEq(buckets.firstBucket(), buckets.uniqueDayTimestamp(block.timestamp +  5 days));
        assertEq(buckets.lastBucket(), buckets.uniqueDayTimestamp(block.timestamp +  5 days));

        // add second bucket after first
        buckets.add(block.timestamp + 10 days, amount);
        assertEq(buckets.calcSum(), 200 ether);
        // still same first bucket
        assertEq(buckets.firstBucket(), buckets.uniqueDayTimestamp(block.timestamp +  5 days));
        // new last bucket
        assertEq(buckets.lastBucket(), buckets.uniqueDayTimestamp(block.timestamp +  10 days));

        // add before first bucket
        buckets.add(block.timestamp + 3 days, amount);
        assertEq(buckets.calcSum(), 300 ether);
        // new first bucket
        assertEq(buckets.firstBucket(), buckets.uniqueDayTimestamp(block.timestamp +  3 days));
        // same bucket
        assertEq(buckets.lastBucket(), buckets.uniqueDayTimestamp(block.timestamp +  10 days));
    }

    function testAddBuckets() public {
        addBuckets();
    }

    function testRemoveMiddleBucket() public {
        addBuckets();
        // remove bucket in the middle
        buckets.remove(block.timestamp + 5 days);
        assertEq(buckets.calcSum(), 200 ether);
        assertEq(buckets.firstBucket(), buckets.uniqueDayTimestamp(block.timestamp +  3 days));
        // same bucket
        assertEq(buckets.lastBucket(), buckets.uniqueDayTimestamp(block.timestamp +  10 days));
    }

    function testRemoveLastBucket() public {
        addBuckets();
        // remove bucket in the middle
        buckets.remove(block.timestamp + 10 days);
        assertEq(buckets.calcSum(), 200 ether);
        assertEq(buckets.firstBucket(), buckets.uniqueDayTimestamp(block.timestamp +  3 days));
        // same bucket
        assertEq(buckets.lastBucket(), buckets.uniqueDayTimestamp(block.timestamp +  5 days));
    }

    function testRemoveFirstBucket() public {
        addBuckets();
        // remove bucket in the middle
        buckets.remove(block.timestamp + 3 days);
        assertEq(buckets.calcSum(), 200 ether);
        assertEq(buckets.firstBucket(), buckets.uniqueDayTimestamp(block.timestamp +  5 days));
        // same bucket
        assertEq(buckets.lastBucket(), buckets.uniqueDayTimestamp(block.timestamp +  10 days));
    }

    function testRemoveAllBuckets() public {
        addBuckets();
        buckets.remove(block.timestamp + 5 days);
        buckets.remove(block.timestamp + 10 days);
        assertEq(buckets.calcSum(), 100 ether);
        assertEq(buckets.firstBucket(), buckets.uniqueDayTimestamp(block.timestamp +  3 days));
        assertEq(buckets.lastBucket(), buckets.uniqueDayTimestamp(block.timestamp +  3 days));

        // remove last one
        buckets.remove(block.timestamp + 3 days);
        assertEq(buckets.firstBucket(), 0);
        assertEq(buckets.lastBucket(), 0);

        assertEq(buckets.calcSum(), 0);

        // add some buckets again to see if everything is still correct
        buckets.add(block.timestamp + 21 days, 3 ether);
        buckets.add(block.timestamp + 24 days, 3 ether);
        assertEq(buckets.calcSum(), 6 ether);
    }
}
