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

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract AdminUser is DSTest{
    // --- Data ---

    ShelfLike shelf;
    PileLike pile;
    CeilingLike ceiling;
    Title title;
    TDistributorLike distributor;

    constructor (address shelf_, address pile_, address ceiling_, address title_, address distributor_) public {
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        ceiling = CeilingLike(ceiling_);
        title = Title(title_);
        distributor = TDistributorLike(distributor_);
        
    }

    function setCeiling(uint loan, uint principal) public {
        ceiling.file(loan, principal);
    }

    function doAdmit(address registry, uint nft, uint principal, address usr) public returns (uint) {
        uint loan = title.issue(usr);
        setCeiling(loan, principal);
        shelf.file(loan, registry, nft);
        return loan;
    }

    function doInitRate(uint rate, uint speed) public {
        pile.file(rate, speed);
    }

    function doAddRate(uint loan, uint rate) public {
        pile.setRate(loan, rate);
    }

    function addKeeper(address usr) public {
        // CollectDeployer cd = CollectDeployer(address(collectDeployer()));
        // cd.collector().rely(usr);
    }

    function doAddKeeper(address usr) public {
        // CollectDeployer cd = CollectDeployer(address(collectDeployer()));
        // cd.collector().rely(usr);
    }
}