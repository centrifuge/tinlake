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

pragma solidity >=0.4.24;

import { Title } from "tinlake-title/title.sol";
import { LightSwitch } from "./lightswitch.sol";
import { Shelf } from "./shelf.sol";
import { Desk } from "./test/simple/desk.sol";
import { Admit } from "./admit.sol";
import { Admin } from "./admin.sol";
import { Pile } from "./pile.sol";
import { Collector } from "./collect/collector.sol";
import { Principal } from "./ceiling/principal.sol";

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
   function newShelf(address tkn_, address title_, address debt_, address Principal_) public returns (Shelf shelf) {
        shelf = new Shelf(tkn_, title_, debt_, Principal_);
        shelf.rely(msg.sender);
        shelf.deny(address(this));
    }
}

contract DeskFab {
    // note: this is the mock Desk, which will interface with the lender/tranche side of Tinlake, and does not require auth for now.
    function newDesk(address shelf_, address token_) public returns (Desk desk) {
        desk = new Desk(shelf_, token_);
        return desk;
    }
}

contract AdmitFab {
    function newAdmit(address title, address shelf, address principal) public returns (Admit admit) {
        admit = new Admit(title, shelf, principal);
        admit.rely(msg.sender);
        admit.deny(address(this));
    }
}

contract AdminFab {
    function newAdmin(address admit, address appraiser, address pile) public returns(Admin admin) {
        admin = new Admin(admit, appraiser, pile);
        admin.rely(msg.sender);
        admin.deny(address(this));
    }
}

contract CollectorFab {
    function newCollector(address desk, address shelf, address pile, address liquidation) public returns (Collector collector) {
        collector = new Collector(desk, shelf, pile, liquidation);
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

contract Deployer {
    TitleFab          titlefab;
    LightSwitchFab    lightswitchfab;
    ShelfFab          shelffab;
    DeskFab           deskfab;
    AdmitFab          admitfab;
    AdminFab          adminfab;
    PileFab           pilefab;
    PrincipalFab      principalFab;
    CollectorFab      collectorFab;

    address     public god;
    address     public appraiser_;

    Title       public title;
    LightSwitch public lightswitch;
    Shelf       public shelf;
    Desk        public desk;
    Admit       public admit;
    Admin       public admin;
    LenderLike  public lender;
    Pile        public pile;
    Principal   public principal;


    constructor (address god_, TitleFab titlefab_, LightSwitchFab lightswitchfab_, ShelfFab shelffab_, DeskFab deskfab_, AdmitFab admitfab_, AdminFab adminfab_, PileFab pilefab_, PrincipalFab principalFab_) public {
        god = god_;

        titlefab = titlefab_;
        lightswitchfab = lightswitchfab_;
        shelffab = shelffab_;
        deskfab = deskfab_;
        admitfab = admitfab_;
        adminfab = adminfab_;
        pilefab = pilefab_;
        principalFab = principalFab_;
    }

    function deployCollect(address collectDeployer_ , uint threshold_) public {
        //collectDeployer = CollectDeployerLike(collectDeployer_);
        //collectDeployer.deploy(address(pile), address(shelf), address(pile), address(desk), threshold_);
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
    //and the Pile should articulate that it depends on the Desk, not a generic "lender".
    function deployDesk(address currency_) public {
        desk = deskfab.newDesk(address(shelf), currency_);
        shelf.depend("lender", address(desk));
    }

    function deployAdmit() public {
        admit = admitfab.newAdmit(address(title), address(shelf), address(principal));
        admit.rely(god);
    }

    function deployAdmin(address appraiser) public {
        appraiser_ = appraiser;
        admin = adminfab.newAdmin(address(admit), appraiser_, address(pile));
        admin.rely(god);
    }

    function deployPrincipal() public {
        principal = principalFab.newPrincipal();
        principal.rely(god);
    }

    function deploy() public {
        address desk_ = address(desk);
        address admit_ = address(admit);
        address admin_ = address(admin);
        address shelf_ = address(shelf);

        // desk allowed to call
        shelf.rely(desk_);
        

        // admit allowed to call
        title.rely(admit_);
        shelf.rely(admit_);
        principal.rely(admit_);

        //admin allowed to call
        admit.rely(admin_);
        shelf.rely(admin_);
        pile.rely(admin_);

        // shelf allowed to call
        pile.rely(shelf_);
        principal.rely(shelf_);

        // collect contracts
        // TODO: shelf.rely(address(collectDeployer.collector()));

        WardsLike(appraiser_).rely(admin_);
    }
}

