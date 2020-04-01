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

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract AdminUser {
    // --- Data ---

    ShelfLike shelf;
    PileLike pile;
    CeilingLike ceiling;
    Title title;
    TDistributorLike distributor;
    CollectorLike collector;
    ThresholdLike threshold;

    constructor (address shelf_, address pile_, address ceiling_, address title_, address distributor_, address collector_, address threshold_) public {
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        ceiling = CeilingLike(ceiling_);
        title = Title(title_);
        distributor = TDistributorLike(distributor_);
        collector = CollectorLike(collector_);
        threshold = ThresholdLike(threshold_);
    }

    function setCeiling(uint loan, uint principal) public {
        ceiling.file("loan", loan, principal);
    }

    function doInitRate(uint rate, uint speed) public {
        pile.file("rate", rate, speed);
    }

    function doAddRate(uint loan, uint rate) public {
        pile.setRate(loan, rate);
    }

    function setCollectPrice(uint loan, uint price) public {
        collector.file("loan", loan, address(0), price);
    }

    function addKeeper(uint loan, address usr, uint price) public {
        collector.file("loan", loan, usr, price);
    }

    function whitelistKeeper(address usr) public {
        collector.relyCollector(usr);
    }

    function setThreshold(uint loan, uint currencyAmount) public {
        threshold.set(loan, currencyAmount);
    }

    function collect(uint loan, address usr) public {
        collector.collect(loan, usr);
    }

}
