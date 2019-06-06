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
import { Reception } from "./reception.sol"; 
import { Desk } from "./desk.sol";
import { Pile } from "./pile.sol";
import { Collateral } from "./collateral.sol";
import { Valve } from "./valve.sol";
import { Admit } from "./admit.sol";

contract LenderFabLike {
    function deploy(address,address,address) public returns (address);
}

contract LenderLike {
    function rely(address) public;
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
   function newPile(address tkn) public returns (Pile pile) {
        pile = new Pile(tkn);
        pile.rely(msg.sender);
        pile.deny(address(this));
    }
}

contract ShelfFab {
   function newShelf(address pile, address appraiser) public returns (Shelf shelf) {
        shelf = new Shelf(pile, appraiser);
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

contract Deployer {
    TitleFab titlefab;
    LightSwitchFab lightswitchfab;
    PileFab pilefab;
    ShelfFab shelffab;
    CollateralFab collateralfab;
    
    Title       public title;
    LightSwitch public lightswitch;
    Pile        public pile;
    Shelf       public shelf;
    Collateral  public collateral;
    Valve       public valve;
    address     public god; 
    Desk        public desk;
    Reception   public reception;
    Admit       public admit;
    LenderLike  public lender;

    constructor (address god_, TitleFab titlefab_, LightSwitchFab lightswitchfab_, PileFab pilefab_, ShelfFab shelffab_, CollateralFab collateralfab_) public {
        address self = msg.sender;
        god = god_;
        
        titlefab = titlefab_;
        lightswitchfab = lightswitchfab_;
        pilefab = pilefab_;
        shelffab = shelffab_;
        collateralfab = collateralfab_;
    }

    function deployTitle(string memory name, string memory symbol) public {
        title = titlefab.newTitle(name, symbol);
        title.rely(address(this));
        title.rely(god);
    }

    function deployLightSwitch() public {
        lightswitch = lightswitchfab.newLightSwitch();
        lightswitch.rely(address(this));
        lightswitch.rely(god);
    }  
  
    function deployCollateral() public {
        collateral = collateralfab.newCollateral();
        collateral.rely(address(this));
        collateral.rely(god);
    }
    function deployPile(address currency_) public {
        pile = pilefab.newPile(currency_);
        pile.rely(god);
    }
    function deployShelf(address appraiser_) public {
        shelf = shelffab.newShelf(address(pile), appraiser_);
        shelf.rely(god);
        pile.rely(address(shelf));
    }
    function deployValve() public {
        valve = new Valve(address(collateral), address(shelf));
        valve.rely(god); 
        collateral.rely(address(valve));
    } 
    function deploy(address currency_, address lenderfab_) public {
        address pile_ = address(pile);
        address shelf_ = address(shelf);
        address valve_ = address(valve);

        // LenderFab deploys a lender with the defined collateral and currency
        address lender_ = LenderFabLike(lenderfab_).deploy(currency_, address(collateral), address(lightswitch));

        lender = LenderLike(lender_);
        lender.rely(god);

        //set lender in pile
        pile.setLender(lender_);
        
        desk = new Desk(pile_, lender_, valve_, address(collateral), address(lightswitch));
        desk.rely(god);
        address desk_ = address(desk);
        pile.rely(desk_);
        valve.rely(desk_);
        desk.approve(lender_, uint(-1));

        admit = new Admit(address(title), shelf_);
        admit.rely(god);
        address admit_ = address(admit);
        title.rely(admit_);
        shelf.rely(admit_);

        reception = new Reception(desk_, address(title), shelf_, pile_);
        reception.rely(god);
        address reception_ = address(reception);
        shelf.rely(reception_);
        pile.rely(reception_);
        desk.rely(reception_);

    }
}

