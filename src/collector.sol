// collector.sol the collector contract can remove bad assets from the pool
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


contract SpotterLike {
    function collectable(uint loan) public returns(bool);
}

contract Collector {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    SpotterLike spotter;

    constructor (address spotter_) public {
        spotter = SpotterLik(spotter_);
    }

    function file(bytes32 what, uint data) public auth {
        if (what == "threshold") threshold = data;
        else revert();
    }

    modifier collectable (uint loan) { require(spotter.overdue(loan) == true); _; }


    function collect(uint loan, address usr, uint wad) public collectable(loan) auth {
        pile.repay(loan, wad, msg.sender);
        shelf.free(loan, usr);
        desk.balance();
    }


}