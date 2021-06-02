// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.15;

// the buckets contract stores values in a map using a timestamp as a key
// each value store a pointer the next value in a linked list
// to improve performance/gas efficiency while iterating over all values in a timespan
contract Buckets {
    // abstract contract
    constructor() {}

    struct Bucket {
        uint value;
        uint next;
    }

    // timestamp => bucket
    mapping (uint => Bucket) public buckets;

    // pointer to the first bucket and last bucket
    uint public firstBucket;
    uint public lastBucket;

    uint constant public NullDate = 1;

    function addBucket(uint timestamp, uint value) internal {
        buckets[timestamp].value = value;

        if (firstBucket == 0) {
            firstBucket = timestamp;
            buckets[timestamp].next = NullDate;
            lastBucket = firstBucket;
            return;
        }

        // new bucket before first one
        if (timestamp < firstBucket) {
            buckets[timestamp].next = firstBucket;
            firstBucket = timestamp;
            return;
        }

        // find predecessor bucket by going back in time
        // instead of iterating the linked list from the first bucket
        // assuming its more gas efficient to iterate over time instead of iterating the list from the beginning
        // not true if buckets are only sparsely populated over long periods of time
        uint prev = timestamp;
        while(buckets[prev].next == 0) {prev = prev - 1 days;}

        if (buckets[prev].next == NullDate) {
            lastBucket = timestamp;
        }
        buckets[timestamp].next = buckets[prev].next;
        buckets[prev].next = timestamp;
    }

    function removeBucket(uint timestamp) internal {
        buckets[timestamp].value = 0;
        _removeBucket(timestamp);
        buckets[timestamp].next = 0;
    }

    function _removeBucket(uint timestamp) internal {
        if(firstBucket == lastBucket) {
            lastBucket = 0;
            firstBucket = 0;
            return;
        }

        if (timestamp != firstBucket) {
            uint prev = timestamp - 1 days;
            // assuming its more gas efficient to iterate over time instead of iterating the list from the beginning
            // not true if buckets are only sparsely populated over long periods of time
            while(buckets[prev].next != timestamp) {prev = prev - 1 days;}
            buckets[prev].next = buckets[timestamp].next;
            if(timestamp == lastBucket) {
                lastBucket = prev;
            }
            return;
        }

        firstBucket = buckets[timestamp].next;
    }
}
