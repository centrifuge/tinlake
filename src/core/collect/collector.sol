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

pragma solidity >=0.4.24;

contract SpotterLike {
    function collectable(uint loan) public returns(bool);
    function seizure(uint loan) public;
    function free(uint loan, address usr) public;
}

contract TagLike {
    function price(uint loan) public returns(uint);
}

contract DeskLike {
    function balance() public;
}

contract PileLike {
    function recovery(uint loan, uint wad) public;
}

contract Collector {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    SpotterLike spotter;
    TagLike tag;
    DeskLike desk;
    PileLike pile;

    constructor (address spotter_, address tag_, address desk_, address pile_) public {
        spotter = SpotterLike(spotter_);
        tag = TagLike(tag_);
        desk = DeskLike(desk_);
        pile = PileLike(pile_);
        wards[msg.sender] = 1;
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "spotter") spotter = SpotterLike(addr);
        else if (what == "tag") tag = TagLike(addr);
        else if (what == "desk") desk = DeskLike(desk);
        else if (what == "pile") pile = PileLike(pile);
        else revert();
    }

    function collect(uint loan, address usr) public auth {
        if(spotter.collectable(loan) == false){
            spotter.seizure(loan);
        }

        uint wad = tag.price(loan);

        pile.recovery(loan, wad);
        spotter.free(loan, usr);
        desk.balance();
    }
}