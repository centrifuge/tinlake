// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Collector } from "./../collect/collector.sol";


contract CollectorFab {
    function newCollector(address shelf, address pile, address threshold) public returns (address) {
        Collector collector = new Collector(shelf, pile, threshold);
        collector.rely(msg.sender);
        collector.deny(address(this));
        return address(collector);
    }
}
