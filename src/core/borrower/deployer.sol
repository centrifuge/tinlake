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
import { LightSwitch } from "./lightswitch.sol";
import { Shelf } from "./shelf.sol";
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

contract BorrowerDeployer is Auth {
    TitleFab          titlefab;
    LightSwitchFab    lightswitchfab;
    ShelfFab          shelffab;
    PileFab           pilefab;
    PrincipalFab      principalFab;
    CollectorFab      collectorFab;
    ThresholdFab      thresholdFab;

    address     public mainDeployer;

    Title       public title;
    LightSwitch public lightswitch;
    Shelf       public shelf;
    LenderLike  public lender;
    Pile        public pile;
    Principal   public principal;
    Collector   public collector;
    PushRegistry public threshold;


    address public deployUser;


    constructor (address mainDeployer_, TitleFab titlefab_, LightSwitchFab lightswitchfab_, ShelfFab shelffab_, PileFab pilefab_, PrincipalFab principalFab_, CollectorFab collectorFab_, ThresholdFab thresholdFab_) public {
        deployUser = msg.sender;
        mainDeployer = mainDeployer_;

        wards[deployUser] = 1;
        wards[mainDeployer] = 1;



        titlefab = titlefab_;
        lightswitchfab = lightswitchfab_;
        shelffab = shelffab_;

        pilefab = pilefab_;
        principalFab = principalFab_;
        collectorFab = collectorFab_;
        thresholdFab = thresholdFab_;
    }

    function deployThreshold() public auth {
        threshold = thresholdFab.newThreshold();
        threshold.rely(mainDeployer);

    }
    function deployCollector() public auth {
        collector = collectorFab.newCollector(address(shelf), address(pile), address(threshold));
        collector.rely(mainDeployer);
    }

    function deployPile() public auth {
        pile = pilefab.newPile();
        pile.rely(mainDeployer);
    }

    function deployTitle(string memory name, string memory symbol) public auth {
        title = titlefab.newTitle(name, symbol);
        title.rely(mainDeployer);
    }

    function deployLightSwitch() public auth {
        lightswitch = lightswitchfab.newLightSwitch();
        lightswitch.rely(mainDeployer);
    }

    function deployShelf(address currency_) public auth {
        shelf = shelffab.newShelf(currency_, address(title), address(pile), address(principal));
        shelf.rely(mainDeployer);
    }

    function deployPrincipal() public auth {
        principal = principalFab.newPrincipal();
        principal.rely(mainDeployer);
    }

    function deploy() public auth {
        address shelf_ = address(shelf);
        address collector_ = address(collector);

        // shelf allowed to call
        pile.rely(shelf_);
        principal.rely(shelf_);

        // collector allowed to call
        shelf.rely(collector_);

        // remove access of deployUser
        deny(deployUser);
    }

}

