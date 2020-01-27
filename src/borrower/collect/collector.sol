// collector.sol -- can remove bad assets from the pool
// Copyright (C) 2020 Centrifuge

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

import "tinlake-registry/registry.sol";
import "ds-note/note.sol";
import "tinlake-auth/auth.sol";

contract NFTLike {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) public;
}

contract DistributorLike {
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

    struct Option {
        address buyer;
        uint    nftPrice;
    }

    mapping (uint => Option) public options;

    DistributorLike distributor;
    ShelfLike shelf;
    PileLike pile;

    constructor (address shelf_, address pile_, address threshold_) public {
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        threshold = RegistryLike(threshold_);
        wards[msg.sender] = 1;
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "distributor") distributor = DistributorLike(addr);
        else if (what == "shelf") shelf = ShelfLike(addr);
        else if (what == "pile") pile = PileLike(addr);
        else if (what == "threshold") threshold = RegistryLike(addr);
        else revert();
    }

    // --- Collector ---
    function file(uint loan, address buyer, uint nftPrice) public auth {
        require(nftPrice > 0, "no-nft-price-defined");
        options[loan] = Option(buyer, nftPrice);
    }

    function seize(uint loan) public {
        uint debt = pile.debt(loan);
        require((threshold.get(loan) <= debt), "threshold-not-reached");
        shelf.claim(loan, address(this));
    }

    function collect(uint loan) public auth_collector {
        _collect(loan, msg.sender);
    }

    function collect(uint loan, address buyer) public auth {
        _collect(loan, buyer);
    }

    function _collect(uint loan, address buyer) internal {
        require(buyer == options[loan].buyer || options[loan].buyer == address(0));
        (address registry, uint nft) = shelf.token(loan);
        require(options[loan].nftPrice > 0, "no-nft-price-defined");
        shelf.recover(loan, buyer, options[loan].nftPrice);
        NFTLike(registry).transferFrom(address(this), buyer, nft);
        distributor.balance();
    }
}
