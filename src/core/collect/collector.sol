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

contract NFTLike {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) public;
}

contract DeskLike {
    function balance() public;
}

contract PileLike {
    function loans(uint loan) public returns (uint, uint, uint);
    function recovery(uint loan, address usr, uint wad) public;
}

contract RegistryLike {
    function get(uint) public returns (uint);
}

contract ShelfLike {
    function claim(uint, address) public;
    function token(uint loan) public returns (address, uint);
}

contract Collector {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    RegistryLike threshold;
    struct Lot {
        address usr;
        uint    wad;
    }
    mapping (uint => Lot) public tags;

    DeskLike  desk;
    PileLike  pile;
    ShelfLike shelf;

    constructor (address desk_, address pile_, address shelf_, address threshold_) public {
        desk = DeskLike(desk_);
        pile = PileLike(pile_);
        shelf = ShelfLike(shelf_);
        threshold = RegistryLike(threshold_);
        wards[msg.sender] = 1;
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "desk") desk = DeskLike(addr);
        else if (what == "shelf") shelf = ShelfLike(addr);
        else if (what == "pile") pile = PileLike(addr);
        else if (what == "threshold") threshold = RegistryLike(addr);
        else revert();
    }

    // --- Collector ---
    function file(uint loan, address usr, uint wad) public auth {
        tags[loan] = Lot(usr, wad);
    }

    function seize(uint loan) public {
        (uint debt,,) = pile.loans(loan); // TODO: call debt registry or similar
        require((threshold.get(loan) >= debt), "threshold-not-reached");
        shelf.claim(loan, address(this));
    }

    function collect(uint loan) public auth {
        require(msg.sender == tags[loan].usr || tags[loan].usr == address(0));
        // TODO: reentrancy?
        (address registry, uint nft) = shelf.token(loan);
        NFTLike(registry).transferFrom(address(this), msg.sender, nft);
        pile.recovery(loan, msg.sender, tags[loan].wad);
        desk.balance();
    }
}
