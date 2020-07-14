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


import { ShelfFab} from "./fabs/shelf.sol";
import { CollectorFab} from "./fabs/collector.sol";
import { PileFab} from "./fabs/pile.sol";
import { TitleFab} from "./fabs/title.sol";
import { PrincipalCeilingFab} from "./fabs/principal.sol";
import { CreditLineCeilingFab} from "./fabs/creditline.sol";
import { ThresholdFab} from "./fabs/threshold.sol";
import { PricePoolFab} from "./fabs/pricepool.sol";
import { NFTFeedFab} from "./fabs/nftfeed.sol";


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

