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

contract TagLike {
    function price(uint loan) public returns(uint);
}

contract DeskLike {
    function balance() public;
}

contract PileLike {
    function recovery(uint loan, address usr, uint wad) public;
}

contract RegistryLike {
    function get(uint) public returns (uint);
}

contract Collector {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    RegistryLike liquidation;
    TagLike tag;
    DeskLike desk;
    PileLike pile;

    constructor (address tag_, address desk_, address pile_) public {
        tag = TagLike(tag_);
        desk = DeskLike(desk_);
        pile = PileLike(pile_);
        wards[msg.sender] = 1;
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "tag") tag = TagLike(addr);
        else if (what == "desk") desk = DeskLike(addr);
        else if (what == "pile") pile = PileLike(addr);
        else if (what == "liquidation") liquidation = RegistryLike(addr);
        else revert();
    }

    function seize(uint loan) public {
        require((liquidation.get(loan) >= pile.debt(loan)), "threshold-not-reached");
        shelf.free(loan);
    }

    function collect(uint loan, address usr) public auth {
        uint wad = tag.price(loan);

        pile.recovery(loan, msg.sender, wad);
        desk.balance();
    }
}
