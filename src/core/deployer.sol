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

import { Title } from "tinlake-title/title.sol";
import { LightSwitch } from "./lightswitch.sol";
import { Shelf } from "./shelf.sol";
import { TrancheManager } from "./test/simple/trancheManager.sol";
import { Pile } from "./pile.sol";
import { Collector } from "./collect/collector.sol";
import { Principal } from "./ceiling/principal.sol";
import { PushRegistry } from 'tinlake-registry/registry.sol';

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

contract LightSwitchFab {
   function newLightSwitch() public returns (LightSwitch lightswitch) {
        lightswitch = new LightSwitch();
        lightswitch.rely(msg.sender);
        lightswitch.deny(address(this));
    }
}

contract ShelfFab {
   function newShelf(address tkn_, address title_, address debt_, address principal_) public returns (Shelf shelf) {
        shelf = new Shelf(tkn_, title_, debt_, principal_);
        shelf.rely(msg.sender);
        shelf.deny(address(this));
    }
}

contract TrancheManagerFab {
    // note: this is the mock TrancheManager, which will interface with the lender/tranche side of Tinlake, and does not require auth for now.
    function newTrancheManager(address shelf_, address token_) public returns (TrancheManager trancheManager) {
        trancheManager = new TrancheManager(shelf_, token_);
        return trancheManager;
    }
}

contract CollectorFab {
    function newCollector(address trancheManager, address shelf, address pile, address threshold) public returns (Collector collector) {
        collector = new Collector(trancheManager, shelf, pile, threshold);
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

contract Deployer {
    TitleFab          titlefab;
    LightSwitchFab    lightswitchfab;
    ShelfFab          shelffab;
    TrancheManagerFab    trancheManagerFab;
    PileFab           pilefab;
    PrincipalFab      principalFab;
    CollectorFab      collectorFab;
    ThresholdFab      thresholdFab;

    address     public god;

    Title       public title;
    LightSwitch public lightswitch;
    Shelf       public shelf;
    TrancheManager  public trancheManager;
    LenderLike  public lender;
    Pile        public pile;
    Principal   public principal;
    Collector   public collector;
    PushRegistry public threshold;


    constructor (address god_, TitleFab titlefab_, LightSwitchFab lightswitchfab_, ShelfFab shelffab_, TrancheManagerFab trancheManagerFab_, PileFab pilefab_, PrincipalFab principalFab_, CollectorFab collectorFab_, ThresholdFab thresholdFab_) public {
        god = god_;

        titlefab = titlefab_;
        lightswitchfab = lightswitchfab_;
        shelffab = shelffab_;
        trancheManagerFab = trancheManagerFab_;
        pilefab = pilefab_;
        principalFab = principalFab_;
        collectorFab = collectorFab_;
        thresholdFab = thresholdFab_;
    }

    function deployThreshold() public {
        threshold = thresholdFab.newThreshold();
        threshold.rely(god);

    }
    function deployCollector() public {
        collector = collectorFab.newCollector(address(trancheManager), address(shelf), address(pile), address(threshold));
        collector.rely(god);
    }

    function deployPile() public {
        pile = pilefab.newPile();
        pile.rely(god);
    }

    function deployTitle(string memory name, string memory symbol) public {
        title = titlefab.newTitle(name, symbol);
        title.rely(god);
    }

    function deployLightSwitch() public {
        lightswitch = lightswitchfab.newLightSwitch();
        lightswitch.rely(god);
    }

    function deployShelf(address currency_) public {
        shelf = shelffab.newShelf(currency_, address(title), address(pile), address(principal));
        shelf.rely(god);
    }

    // note: this method will be refactored with the new lender side contracts, we will rely on God once more
    //and the Pile should articulate that it depends on the TrancheManager, not a generic "lender".
    function deployTrancheManager(address currency_) public {
        trancheManager = trancheManagerFab.newTrancheManager(address(shelf), currency_);
        shelf.depend("lender", address(trancheManager));
    }

    function deployPrincipal() public {
        principal = principalFab.newPrincipal();
        principal.rely(god);
    }

    function deploy() public {
        address trancheManager_ = address(trancheManager);
        address shelf_ = address(shelf);
        address collector_ = address(collector);

        // trancheManager allowed to call
        shelf.rely(trancheManager_);
      
        // shelf allowed to call
        pile.rely(shelf_);
        principal.rely(shelf_);

        // collector allowed to call
        shelf.rely(collector_);
    }
}

