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
import { Shelf } from "./shelf.sol";
import { Pile } from "./pile.sol";
import { Collector } from "./collect/collector.sol";
import { Principal } from "./ceiling/principal.sol";
import { CreditLine } from "./ceiling/creditline.sol";
import { ThresholdRegistry } from "./collect/registry/threshold.sol";
import { PricePool } from "./price/pool.sol";
import { BaseNFTFeed } from "tinlake-nftfeed/nftfeed.sol";

contract DependLike {
    function depend(bytes32, address) public;
}

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
}

contract CeilingFab {
    function newCeiling(address pile) public returns (address);
}

contract NFTFeedLike {
    function init() public;
}

contract PileFab {
    function newPile() public returns (address) {
        Pile pile = new Pile();
        pile.rely(msg.sender);
        pile.deny(address(this));
        return address(pile);
    }
}

contract TitleFab {
    function newTitle(string memory name, string memory symbol) public returns (address) {
        Title title = new Title(name, symbol);
        title.rely(msg.sender);
        title.deny(address(this));
        return address(title);
    }
}

contract ShelfFab {
    function newShelf(address tkn_, address title_, address debt_, address ceiling_) public returns (address) {
        Shelf shelf = new Shelf(tkn_, title_, debt_, ceiling_);
        shelf.rely(msg.sender);
        shelf.deny(address(this));
        return address(shelf);
    }
}

contract CollectorFab {
    function newCollector(address shelf, address pile, address threshold) public returns (address) {
        Collector collector = new Collector(shelf, pile, threshold);
        collector.rely(msg.sender);
        collector.deny(address(this));
        return address(collector);
    }
}

contract CreditLineCeilingFab {
    function newCeiling(address pile) public returns (address) {
        CreditLine ceiling = new CreditLine(pile);
        ceiling.rely(msg.sender);
        ceiling.deny(address(this));
        return address(ceiling);
    }
}

contract PrincipalCeilingFab {
    function newCeiling(address pile) public returns (address) {
        Principal ceiling = new Principal();
        ceiling.rely(msg.sender);
        ceiling.deny(address(this));
        return address(ceiling);
    }
}

contract ThresholdFab {
    function newThreshold() public returns (address) {
        ThresholdRegistry threshold = new ThresholdRegistry();
        threshold.rely(msg.sender);
        threshold.deny(address(this));
        return address(threshold);
    }
}

contract PricePoolFab {
    function newPricePool() public returns (address) {
        PricePool pricePool = new PricePool();
        pricePool.rely(msg.sender);
        pricePool.deny(address(this));
        return address(pricePool);
    }
}

contract NFTFeedFab {
    function newNFTFeed() public returns (address) {
        BaseNFTFeed feed = new BaseNFTFeed();
        feed.rely(msg.sender);
        feed.deny(address(this));
        return address(feed);
    }
}

contract BorrowerDeployer {
    address      public root;

    TitleFab     public titlefab;
    ShelfFab     public shelffab;
    PileFab      public pilefab;
    CeilingFab   public ceilingFab;
    CollectorFab public collectorFab;
    ThresholdFab public thresholdFab;
    PricePoolFab public pricePoolFab;
    NFTFeedFab   public nftFeedFab;

    address public title;
    address public shelf;
    address public pile;
    address public ceiling;
    address public collector;
    address public threshold;
    address public pricePool;
    address public currency;
    address public nftFeed;

    string       public titleName;
    string       public titleSymbol;

    address constant ZERO = address(0);

    constructor (
      address root_,
      TitleFab titlefab_,
      ShelfFab shelffab_,
      PileFab pilefab_,
      address ceilingFab_,
      CollectorFab collectorFab_,
      ThresholdFab thresholdFab_,
      PricePoolFab pricePoolFab_,
      address nftFeedFab_,
      address currency_,
      string memory titleName_,
      string memory titleSymbol_
    ) public {
        root = root_;

        titlefab = titlefab_;
        shelffab = shelffab_;

        pilefab = pilefab_;
        ceilingFab = CeilingFab(ceilingFab_);
        collectorFab = collectorFab_;
        thresholdFab = thresholdFab_;
        pricePoolFab = pricePoolFab_;
        nftFeedFab = NFTFeedFab(nftFeedFab_);

        currency = currency_;

        titleName = titleName_;
        titleSymbol = titleSymbol_;
    }

    function deployThreshold() public {
        require(threshold == ZERO);
        threshold = thresholdFab.newThreshold();
        AuthLike(threshold).rely(root);
    }

    function deployPricePool() public {
        require(pricePool == ZERO);
        pricePool = pricePoolFab.newPricePool();
        AuthLike(pricePool).rely(root);
    }

    function deployCollector() public {
        require(collector == ZERO && address(shelf) != ZERO);
        collector = collectorFab.newCollector(address(shelf), address(pile), address(threshold));
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
        require(shelf == ZERO && title != ZERO && pile != ZERO && ceiling != ZERO);
        shelf = shelffab.newShelf(currency, address(title), address(pile), address(ceiling));
        AuthLike(shelf).rely(root);
    }

    function deployCeiling() public {
        ceiling = ceilingFab.newCeiling(address(pile));
        AuthLike(ceiling).rely(root);
    }

    function deployNFTFeed() public {
        nftFeed = nftFeedFab.newNFTFeed();
        AuthLike(nftFeed).rely(root);
        threshold = nftFeed;
        ceiling = nftFeed;
    }

    function deploy() public {
        // ensures all required deploy methods were called
        require(shelf != ZERO && collector != ZERO && pricePool != ZERO);

        // shelf allowed to call
        AuthLike(pile).rely(shelf);

        if(nftFeed != address(0)) {
            DependLike(nftFeed).depend("pile", address(pile));
            DependLike(nftFeed).depend("shelf", address(shelf));

            // nft Feed allowed to call pile
            AuthLike(pile).rely(nftFeed);

            NFTFeedLike(nftFeed).init();
            DependLike(shelf).depend("subscriber", address(nftFeed));
        }

        AuthLike(ceiling).rely(shelf);
        AuthLike(title).rely(shelf);

        // collector allowed to call
        AuthLike(shelf).rely(collector);

        // pool needs pile
        DependLike(pricePool).depend("pile", address(pile));
    }

}

