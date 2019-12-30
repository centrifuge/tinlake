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
import { Pile } from "./pile.sol";
import { Admit } from "./admit.sol";
import { Admin } from "./admin.sol";
import { DebtRegister } from "./debt_register.sol";
import {CollectDeployer} from "./collect/deployer.sol";

contract LenderFabLike {
    function deploy(address,address,address) public returns (address);
}

contract CollectDeployerLike {
    function deploy(address pile_, address shelf_, address desk_, uint threshold_) public;
    function spotter() public returns(address);
    function collector() public returns(address);
}

contract LenderLike {
    function rely(address) public;
    function file(address) public;
}

contract WardsLike {
    function rely(address) public;
}

contract DebtRegisterFab {
    function newDebtRegister() public returns (DebtRegister debtRegister) {
        debtRegister = new DebtRegister();
        debtRegister.rely(msg.sender);
        debtRegister.deny(address(this));
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

contract PileFab {
   function newPile(address tkn, address title, address debtRegister) public returns (Pile pile) {
        pile = new Pile(tkn, title, debtRegister);
        pile.rely(msg.sender);
        pile.deny(address(this));
    }
}

contract ShelfFab {
   function newShelf(address pile, address appraiser, address title) public returns (Shelf shelf) {
        shelf = new Shelf(pile, appraiser, title);
        shelf.rely(msg.sender);
        shelf.deny(address(this));
    }
}

contract DeskFab {
    // note: this is the mock Desk, which will interface with the lender/tranche side of Tinlake, and does not require auth for now.
    function newDesk(address pile_, address token_) public returns (Desk desk) {
        desk = new Desk(pile_, token_);
        return desk;
    }
}

contract AdmitFab {
    function newAdmit(address title, address shelf) public returns (Admit admit) {
        admit = new Admit(title, shelf);
        admit.rely(msg.sender);
        admit.deny(address(this));
    }
}

contract AdminFab {
    function newAdmin(address admit, address appraiser, address pile, address debtRegister) public returns(Admin admin) {
        admin = new Admin(admit, appraiser, pile, debtRegister);
        admin.rely(msg.sender);
        admin.deny(address(this));
    }
}

contract Deployer {
    TitleFab titlefab;
    LightSwitchFab lightswitchfab;
    PileFab pilefab;
    ShelfFab shelffab;
    DeskFab deskfab;
    AdmitFab admitfab;
    AdminFab adminfab;
    DebtRegisterFab debtRegisterfab;

    CollectDeployerLike public collectDeployer;

    address     public god;
    address     public appraiser_;

    Title       public title;
    LightSwitch public lightswitch;
    Pile        public pile;
    Shelf       public shelf;
    Desk        public desk;
    Admit       public admit;
    Admin       public admin;
    LenderLike  public lender;
    DebtRegister       public debtRegister;


    constructor (address god_, TitleFab titlefab_, LightSwitchFab lightswitchfab_, PileFab pilefab_, ShelfFab shelffab_, DeskFab deskfab_, AdmitFab admitfab_, AdminFab adminfab_, DebtRegisterFab debtRegisterfab_) public {
        god = god_;

        titlefab = titlefab_;
        lightswitchfab = lightswitchfab_;
        pilefab = pilefab_;
        shelffab = shelffab_;
        deskfab = deskfab_;
        admitfab = admitfab_;
        adminfab = adminfab_;
        debtRegisterfab = debtRegisterfab_;
    }

    function deployCollect(address collectDeployer_ ,uint threshold_) public {
        collectDeployer = CollectDeployerLike(collectDeployer_);
        collectDeployer.deploy(address(pile), address(shelf), address(desk), threshold_);
    }

    function deployDebtRegister() public {
        debtRegister = debtRegisterfab.newDebtRegister();
        debtRegister.rely(god);
    }

    function deployTitle(string memory name, string memory symbol) public {
        title = titlefab.newTitle(name, symbol);
        title.rely(god);
    }

    function deployLightSwitch() public {
        lightswitch = lightswitchfab.newLightSwitch();
        lightswitch.rely(god);
    }

    function deployPile(address currency_) public {
        pile = pilefab.newPile(currency_, address(title), address(debtRegister));
        pile.rely(god);
    }

    function deployShelf(address appraiser) public {
        appraiser_ = appraiser;
        shelf = shelffab.newShelf(address(pile), appraiser_, address(title));
        shelf.rely(god);
        pile.rely(address(shelf));
    }

    // note: this method will be refactored with the new lender side contracts, we will rely on God once more
    //and the Pile should articulate that it depends on the Desk, not a generic "lender".
    function deployDesk(address currency_) public {
        desk = deskfab.newDesk(address(pile), currency_);
        pile.depend("lender", address(desk));
    }

    function deployAdmit() public {
        admit = admitfab.newAdmit(address(title), address(shelf));
        admit.rely(god);
    }

    function deployAdmin(address appraiser) public {
        appraiser_ = appraiser;
        admin = adminfab.newAdmin(address(admit), appraiser_, address(pile), address(debtRegister));
        admin.rely(god);
    }

    function deploy() public {
        address pile_ = address(pile);
        address desk_ = address(desk);
        address admit_ = address(admit);
        address admin_ = address(admin);

        // desk allowed to call
        pile.rely(desk_);

        // admit allowed to call
        title.rely(admit_);
        shelf.rely(admit_);

        // admin allowed to call
        admit.rely(admin_);
        pile.rely(admin_);
        debtRegister.rely(admin_);

        // pile allowed to call
        debtRegister.rely(pile_);

        // collect contracts
        shelf.rely(address(collectDeployer.spotter()));
        pile.rely(address(collectDeployer.collector()));

        WardsLike(appraiser_).rely(admin_);
    }
}

