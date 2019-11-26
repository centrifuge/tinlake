// Copyright (C) 2019 lucasvo

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

import { Title } from "./title.sol";
import { LightSwitch } from "./lightswitch.sol";
import { Shelf } from "./shelf.sol";
import { Desk } from "./desk.sol";
import { Pile } from "./pile.sol";
import { Collateral } from "./collateral.sol";
import { Valve } from "./valve.sol";
import { Admit } from "./admit.sol";
import { Admin } from "./admin.sol";
import { Beans } from "./beans.sol";

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

contract BeansFab {
    function newBeans() public returns (Beans beans) {
        beans = new Beans();
        beans.rely(msg.sender);
        beans.deny(address(this));
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
   function newPile(address tkn, address title, address beans) public returns (Pile pile) {
        pile = new Pile(tkn, title, beans);
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

contract CollateralFab {
    function newCollateral() public returns (Collateral collateral) {
        collateral = new Collateral("CVT", "Collateral Value Token", "something", 0);
        collateral.rely(msg.sender);
        collateral.deny(address(this));
    }
}

contract DeskFab {
    function newDesk(address pile, address valve, address collateral, address lightswitch) public returns (Desk desk) {
        desk = new Desk(pile, valve, collateral, lightswitch);
        desk.rely(msg.sender);
        desk.deny(address(this));
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
    function newAdmin(address admit, address appraiser, address pile, address beans) public returns(Admin admin) {
        admin = new Admin(admit, appraiser, pile, beans);
        admin.rely(msg.sender);
        admin.deny(address(this));
    }
}

contract Deployer {
    TitleFab titlefab;
    LightSwitchFab lightswitchfab;
    PileFab pilefab;
    ShelfFab shelffab;
    CollateralFab collateralfab;
    DeskFab deskfab;
    AdmitFab admitfab;
    AdminFab adminfab;
    BeansFab beansfab;


    address     public god;
    address     public appraiser_;

    Title       public title;
    LightSwitch public lightswitch;
    Pile        public pile;
    Shelf       public shelf;
    Collateral  public collateral;
    Valve       public valve;
    Desk        public desk;
    Admit       public admit;
    Admin       public admin;
    LenderLike  public lender;
    Beans       public beans;

    constructor (address god_, TitleFab titlefab_, LightSwitchFab lightswitchfab_, PileFab pilefab_, ShelfFab shelffab_, CollateralFab collateralfab_, DeskFab deskfab_, AdmitFab admitfab_, AdminFab adminfab_, BeansFab beansfab_) public {
        address self = msg.sender;
        god = god_;
        
        titlefab = titlefab_;
        lightswitchfab = lightswitchfab_;
        pilefab = pilefab_;
        shelffab = shelffab_;
        collateralfab = collateralfab_;
        deskfab = deskfab_;
        admitfab = admitfab_;
        adminfab = adminfab_;
        beansfab = beansfab_;
    }

    function deployBeans() public {
        beans = beansfab.newBeans();
        beans.rely(god);
    }
    
    function deployTitle(string memory name, string memory symbol) public {
        title = titlefab.newTitle(name, symbol);
        title.rely(god);
    }

    function deployLightSwitch() public {
        lightswitch = lightswitchfab.newLightSwitch();
        lightswitch.rely(god);
    }  
  
    function deployCollateral() public {
        collateral = collateralfab.newCollateral();
        collateral.rely(god);
    }

    function deployPile(address currency_) public {
        pile = pilefab.newPile(currency_, address(title), address(beans));
        pile.rely(god);
    }

    function deployShelf(address appraiser) public {
        appraiser_ = appraiser;
        shelf = shelffab.newShelf(address(pile), appraiser_, address(title));
        shelf.rely(god);
        pile.rely(address(shelf));
    }

    function deployValve() public {
        valve = new Valve(address(collateral), address(shelf));
        valve.rely(god); 
        collateral.rely(address(valve));
    } 

    function deployDesk() public {
        desk = deskfab.newDesk(address(pile), address(valve), address(collateral), address(lightswitch));
        desk.rely(god);
    }

    function deployAdmit() public {
        admit = admitfab.newAdmit(address(title), address(shelf));
        admit.rely(god);
    }

    function deployAdmin(address appraiser) public {
        appraiser_ = appraiser;
        admin = adminfab.newAdmin(address(admit), appraiser_, address(pile), address(beans));
        admin.rely(god);
    }
    function deploy() public {
        address pile_ = address(pile);
        address shelf_ = address(shelf);
        address valve_ = address(valve);
        address desk_ = address(desk);
        address admit_ = address(admit);
        address admin_ = address(admin);
        address beans_ = address(beans);

        // desk allowed to call
        pile.rely(desk_);
        valve.rely(desk_);

        // admit allowed to call
        title.rely(admit_);
        shelf.rely(admit_);

        // admin allowed to call
        admit.rely(admin_);
        pile.rely(admin_);
        beans.rely(admin_);

        // pile allowed to call
        beans.rely(pile_);

        WardsLike(appraiser_).rely(admin_);
    }

    function deployLender(address currency_, address lenderfab_) public returns(address) {
        // LenderFab deploys a lender with the defined collateral and currency
        address lender_ = LenderFabLike(lenderfab_).deploy(currency_, address(collateral), address(lightswitch));

        lender = LenderLike(lender_);
        lender.rely(god);
        lender.rely(address(desk));

        desk.approve(lender_, uint(-1));
        pile.depend("lender", lender_);
        desk.depend("lender", lender_);
        return lender_;
    }

}

