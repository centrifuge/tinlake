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

import "./lightswitch.sol";

contract ValveLike {
    function balance(address) public;
    function want() public returns(int);
    function mintMax(address usr) public;
    function burnMax(address usr) public;
    function tkn() public returns(TokenLike);
}

contract TokenLike {
    function approve(address, uint) public;
}

contract LenderLike {
    function provide(address,address,uint,uint) public;
    function release(address,address,uint,uint) public;
    function free(address, uint) public;
}

contract AppraiserLike {
}

contract PileLike {
    function want() public returns (int);
}

contract CollateralLike {
    function balanceOf(address) public returns (uint);
    function approve(address,uint) public;
}

// Desk serves as an interface to manage the lending actions of Tinlake.
contract Desk is Switchable {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    PileLike public pile;
    LenderLike public lender;
    ValveLike public valve;
    CollateralLike public collateral;

    constructor (address pile_, address valve_, address collateral_, address lightswitch_) Switchable(lightswitch_) public {
        wards[msg.sender] = 1;

        pile = PileLike(pile_);
        valve = ValveLike(valve_);
        collateral = CollateralLike(collateral_);

    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "valve") { valve = ValveLike(addr); }
        else if (what == "collateral") { collateral = CollateralLike(addr); }
        else if (what == "lender") { lender = LenderLike(addr); }
        else revert();
    }

    function approve(address usr, uint wad) public auth {
        collateral.approve(usr, wad);
    }

    // --- Desk ---
    function balance() public {
        int wadT = pile.want();
        address self = address(this);

        int wadC = valve.want();
        if (wadC > 0) {
            require(wadT > 0);
            valve.mintMax(address(self));
            // give collateral, want token
            lender.provide(address(self), address(pile), uint(wadC),uint(wadT));

        } else {
            require(wadT <= 0);
            // give token, want collateral
            lender.release(self, address(pile), uint(wadC*-1), uint(wadT*-1));
            valve.tkn().approve(address(valve),uint(-1));
            valve.burnMax(self);
        }
    }
    
    function reduce(uint wad) public auth {
        lender.free(address(this), wad);
        valve.balance(address(this));
    }    
}
