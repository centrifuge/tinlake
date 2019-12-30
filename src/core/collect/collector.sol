// collector.sol -- can remove bad assets from the pool
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

import 'tinlake-registry/registry.sol';

contract DeskLike {
    function balance() public;
}

contract PileLike {
    function recovery(uint loan, address usr, uint wad) public;
}

contract RegistryLike {
    function get(uint) public returns (uint);
}

contract ShelfLike {
    function claim(uint, address) public;
    function lock(uint, uint) public;
}

contract Collector {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    RegistryLike liquidation;
    struct Lot {
        address usr;
        uint    wad;
    }
    mapping (uint => Lot) public tags;

    DeskLike desk;
    PileLike pile;

    constructor (address desk_, address pile_) public {
        desk = DeskLike(desk_);
        pile = PileLike(pile_);
        wards[msg.sender] = 1;
    }

    function depend(bytes32 what, address addr) public auth {
        else if (what == "desk") desk = DeskLike(addr);
        else if (what == "shelf") shelf = ShelfLike(addr);
        else if (what == "pile") pile = PileLike(addr);
        else if (what == "liquidation") liquidation = RegistryLike(addr);
        else revert();
    }

    // --- Collector ---
    function file(uint loan, address usr, uint wad) auth {
        tags[loan] = Lot(usr, wad);
    }

    function seize(uint loan) public {
        require((liquidation.get(loan) >= pile.debt(loan)), "threshold-not-reached");
        shelf.lock(loan, 1);
    }

    function collect(uint loan) public auth {
        uint wad, address usr = tags[loan];
        require(msg.sender == usr);
        shelf.claim(loan, usr);
        pile.recovery(loan, usr, wad);
        desk.balance();
    }
}
