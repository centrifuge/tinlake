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

import "tinlake-auth/auth.sol";

import { Title } from "tinlake-title/title.sol";
import { Shelf } from "./shelf.sol";
import { Pile } from "./pile.sol";
import { Collector } from "./collect/collector.sol";
import { Principal } from "./ceiling/principal.sol";
import { PushRegistry } from 'tinlake-registry/registry.sol';
import { PricePool } from "./price/pool.sol";

contract LenderFabLike {
    function deploy(address,address,address) public returns (address);
}

contract LenderLike {
    function rely(address) public;
    function file(address) public;
}

contract WardsLike {
    function rely(address) public;
}

contract PileFab {
    function newPile() public returns (Pile pile) {
        pile = new Pile();
        pile.rely(msg.sender);
        pile.deny(address(this));
    }
}

contract TitleFab {
    function newTitle(string memory name, string memory symbol) public returns (Title title) {
        title = new Title(name, symbol);
        title.rely(msg.sender);
        title.deny(address(this));
    }
}

contract ShelfFab {
    function newShelf(address tkn_, address title_, address debt_, address principal_) public returns (Shelf shelf) {
        shelf = new Shelf(tkn_, title_, debt_, principal_);
        shelf.rely(msg.sender);
        shelf.deny(address(this));
    }
}

contract CollectorFab {
    function newCollector(address shelf, address pile, address threshold) public returns (Collector collector) {
        collector = new Collector(shelf, pile, threshold);
        collector.rely(msg.sender);
        collector.deny(address(this));
    }
}

contract PrincipalFab {
    function newPrincipal() public returns (Principal principal) {
        principal = new Principal();
        principal.rely(msg.sender);
        principal.deny(address(this));
    }
}

contract ThresholdFab {
    function newThreshold() public returns (PushRegistry threshold) {
        threshold = new PushRegistry();
        threshold.rely(msg.sender);
        threshold.deny(address(this));
    }
}

contract PricePoolFab {
    function newPricePool() public returns (PricePool pricePool) {
        pricePool = new PricePool();
        pricePool.rely(msg.sender);
        pricePool.deny(address(this));
    }
}

contract BorrowerDeployer is Auth {
    TitleFab          titlefab;
    ShelfFab          shelffab;
    PileFab           pilefab;
    PrincipalFab      principalFab;
    CollectorFab      collectorFab;
    ThresholdFab      thresholdFab;
    PricePoolFab      pricePoolFab;

    address     public rootAdmin;

    Title       public title;
    Shelf       public shelf;
    LenderLike  public lender;
    Pile        public pile;
    Principal   public principal;
    Collector   public collector;
    PushRegistry public threshold;
    PricePool   public  pricePool;


    address public deployUser;


    constructor (address rootAdmin_, TitleFab titlefab_, ShelfFab shelffab_, PileFab pilefab_,
        PrincipalFab principalFab_, CollectorFab collectorFab_, ThresholdFab thresholdFab_, PricePoolFab pricePoolFab_) public {
        deployUser = msg.sender;
        rootAdmin = rootAdmin_;

        wards[deployUser] = 1;
        wards[rootAdmin] = 1;


        titlefab = titlefab_;
        shelffab = shelffab_;

        pilefab = pilefab_;
        principalFab = principalFab_;
        collectorFab = collectorFab_;
        thresholdFab = thresholdFab_;
        pricePoolFab = pricePoolFab_;
    }

    function deployThreshold() public auth {
        threshold = thresholdFab.newThreshold();
        threshold.rely(rootAdmin);

    }

    function deployPricePool() public auth {
        pricePool = pricePoolFab.newPricePool();
        pricePool.rely(rootAdmin);
    }

    function deployCollector() public auth {
        collector = collectorFab.newCollector(address(shelf), address(pile), address(threshold));
        collector.rely(rootAdmin);
    }

    function deployPile() public auth {
        pile = pilefab.newPile();
        pile.rely(rootAdmin);
    }

    function deployTitle(string memory name, string memory symbol) public auth {
        title = titlefab.newTitle(name, symbol);
        title.rely(rootAdmin);
    }

    function deployShelf(address currency_) public auth {
        shelf = shelffab.newShelf(currency_, address(title), address(pile), address(principal));
        shelf.rely(rootAdmin);
    }

    function deployPrincipal() public auth {
        principal = principalFab.newPrincipal();
        principal.rely(rootAdmin);
    }

    function deploy() public auth {
        address shelf_ = address(shelf);
        address collector_ = address(collector);

        // ensures all required deploy methods were called
        require(shelf_ != address(0));
        require(collector_ != address(0));
        require(address(pricePool) != address(0));


        // shelf allowed to call
        pile.rely(shelf_);
        principal.rely(shelf_);
        title.rely(shelf_);

        // collector allowed to call
        shelf.rely(collector_);

        // pool needs pile
        pricePool.depend("pile", address(pile));

        // remove access of deployUser
        deny(deployUser);
    }

}

