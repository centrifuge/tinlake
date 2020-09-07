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


import { ShelfFab } from "./fabs/shelf.sol";
import { CollectorFab } from "./fabs/collector.sol";
import { PileFab } from "./fabs/pile.sol";
import { TitleFab } from "./fabs/title.sol";
import { NAVFeedFab } from "./fabs/navfeed.sol";
import { NFTFeedFab } from "./fabs/nftfeed.sol";
import {FixedPoint}      from "./../fixed_point.sol";


contract DependLike {
    function depend(bytes32, address) public;
}

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
}

contract NFTFeedLike {
    function init() public;
}

contract FeedFabLike {
    function newFeed() public returns(address);
}


contract FileLike {
    function file(bytes32 name, uint value) public;
}

contract BorrowerDeployer is FixedPoint {
    address      public root;

    TitleFab     public titlefab;
    ShelfFab     public shelffab;
    PileFab      public pilefab;
    CollectorFab public collectorFab;
    FeedFabLike   public feedFab;

    address public title;
    address public shelf;
    address public pile;
    address public collector;
    address public currency;
    address public feed;

    string  public titleName;
    string  public titleSymbol;
    Fixed27 public discountRate;

    address constant ZERO = address(0);

    constructor (
      address root_,
      TitleFab titlefab_,
      ShelfFab shelffab_,
      PileFab pilefab_,
      CollectorFab collectorFab_,
      address feedFab_,
      address currency_,
      string memory titleName_,
      string memory titleSymbol_,
      uint discountRate_
    ) public {
        root = root_;

        titlefab = titlefab_;
        shelffab = shelffab_;

        pilefab = pilefab_;
        collectorFab = collectorFab_;
        feedFab = FeedFabLike(feedFab_);

        currency = currency_;

        titleName = titleName_;
        titleSymbol = titleSymbol_;
        discountRate = Fixed27(discountRate_);
    }

    function deployCollector() public {
        require(collector == ZERO && address(shelf) != ZERO);
        collector = collectorFab.newCollector(address(shelf), address(pile), address(feed));
        AuthLike(collector).rely(root);
    }

    function deployPile() public {
        require(pile == ZERO);
        pile = pilefab.newPile();
        AuthLike(pile).rely(root);
    }

    function deployTitle() public {
        require(title == ZERO);
        title = titlefab.newTitle(titleName, titleSymbol);
        AuthLike(title).rely(root);
    }

    function deployShelf() public {
        require(shelf == ZERO && title != ZERO && pile != ZERO && feed != ZERO);
        shelf = shelffab.newShelf(currency, address(title), address(pile), address(feed));
        AuthLike(shelf).rely(root);
    }

    function deployFeed() public {
        feed = feedFab.newFeed();
        AuthLike(feed).rely(root);
    }

    function deploy() public {
        // ensures all required deploy methods were called
        require(shelf != ZERO && collector != ZERO);

        // shelf allowed to call
        AuthLike(pile).rely(shelf);

        DependLike(feed).depend("shelf", address(shelf));
        DependLike(feed).depend("pile", address(pile));

        // allow nftFeed to update rate groups
        AuthLike(pile).rely(feed);
        NFTFeedLike(feed).init();

        DependLike(shelf).depend("subscriber", address(feed));

        AuthLike(feed).rely(shelf);
        AuthLike(title).rely(shelf);

        // collector allowed to call
        AuthLike(shelf).rely(collector);

        FileLike(feed).file("discountRate", discountRate.value);
    }
}

