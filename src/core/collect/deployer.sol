// Copyright (C) 2019 Centrifuge

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

pragma solidity >=0.4.23;

// collect contracts
import {Spotter} from "./spotter.sol";
import {Tag} from "./tag.sol";
import {Collector} from "./collector.sol";

contract SpotterFab {
    function newSpotter(address shelf, address pile) public returns(Spotter spotter) {
        spotter = new Spotter(shelf, pile);
        spotter.rely(msg.sender);
        spotter.deny(address(this));
    }
}

contract TagFab {
    function newTag(address pile) public returns(Tag tag) {
        tag = new Tag(pile);
        tag.rely(msg.sender);
        tag.deny(address(this));
    }
}

contract CollectorFab {
    function newCollector(address spotter, address tag, address desk, address pile) public returns(Collector collector) {
        collector = new Collector(spotter, tag, desk, pile);
        collector.rely(msg.sender);
        collector.deny(address(this));
    }
}

contract CollectDeployer {
    SpotterFab spotterFab;
    TagFab tagFab;
    CollectorFab collectorFab;

    address god;

    Spotter public spotter;
    Tag public tag;
    Collector public collector;

    constructor(address god_, SpotterFab spotterFab_, TagFab tagFab_, CollectorFab collectorFab_) public {
        god = god_;
        spotterFab = spotterFab_;
        tagFab = tagFab_;
        collectorFab = collectorFab_;
    }

    function deploy(address pile_, address shelf_, address desk_, uint threshold_) public {
        spotter = spotterFab.newSpotter(shelf_, pile_);
        tag = tagFab.newTag(pile_);
        collector = collectorFab.newCollector(address(spotter), address(tag), desk_, pile_);

        // auth
        spotter.rely(address(collector));

        spotter.file("threshold", threshold_);

        // only god address should control
        crowning(god);
        abdicate(address(this));
    }

    function crowning(address usr) internal {
        spotter.rely(usr);
        tag.rely(usr);
        collector.rely(usr);

    }

    function abdicate(address usr) internal {
        spotter.deny(usr);
        tag.deny(usr);
        collector.deny(usr);
    }
}
