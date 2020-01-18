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
import "ds-note/note.sol";
import "tinlake-auth/auth.sol";

contract NFTLike {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) public;
}

contract Distributor {
    function balance() public;
}

contract RegistryLike {
    function get(uint) public returns (uint);
}

contract PileLike {
    function debt(uint) public returns (uint);
}

contract ShelfLike {
    function claim(uint, address) public;
    function token(uint loan) public returns (address, uint);
    function recover(uint loan, address usr, uint wad) public;
}

contract Collector is DSNote, Auth {
    
     // -- Collectors --
    mapping (address => uint) public collectors;
    function relyCollector(address usr) public auth note { collectors[usr] = 1; }
    function denyCollector(address usr) public auth note { collectors[usr] = 0; }
    modifier auth_collector { require(collectors[msg.sender] == 1); _; }

    // --- Data ---
    RegistryLike threshold;
    struct Lot {
        address usr;
        uint    wad;
    }
    mapping (uint => Lot) public tags;

    Distributor trancheManager;
    ShelfLike shelf;
    PileLike pile;

    constructor (address trancheManager_, address shelf_, address pile_, address threshold_) public {
        trancheManager = Distributor(trancheManager_);
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        threshold = RegistryLike(threshold_);
        wards[msg.sender] = 1;
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "trancheManager") trancheManager = Distributor(addr);
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
        uint debt = pile.debt(loan);
        require((threshold.get(loan) <= debt), "threshold-not-reached");
        shelf.claim(loan, address(this));
    }

    function collect(uint loan, address usr) public auth_collector {
        require(usr == tags[loan].usr || tags[loan].usr == address(0));
        (address registry, uint nft) = shelf.token(loan);
        shelf.recover(loan, usr, tags[loan].wad);
        NFTLike(registry).transferFrom(address(this), usr, nft);
        trancheManager.balance();
    }
}
