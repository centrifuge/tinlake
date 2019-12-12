// spotter.sol -- monitors the pool detect collectable assets
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

contract ShelfLike {
    function adjust(uint loan) public;
    function shelf(uint loan) public returns (address, uint256, uint, uint);
    function free(uint loan, address usr) public;
}

contract SPileLike {
    function loans(uint loan) public returns (uint, uint, uint ,uint);
    function debtOf(uint loan) public returns (uint);
    function collect(uint loan) public;
}

contract NFTLike {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) public;
}

contract Spotter {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }


    ShelfLike public shelf;
    SPileLike public pile;

    // in rad 10**27
    uint public threshold;

    constructor(address shelf_, address pile_) public {
        wards[msg.sender] = 1;
        shelf = ShelfLike(shelf_);
        pile = SPileLike(pile_);
    }

    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, ONE), y / 2) / y;
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }


    function file(bytes32 what, uint data) public auth {
        if (what == "threshold") threshold = data;
        else revert();
    }

    function nowPrice(uint loan) internal returns(uint) {
        shelf.adjust(loan);
        (,,uint price,) = shelf.shelf(loan);
        return price;
    }

    function nowDebt(uint loan) internal returns(uint) {
        pile.collect(loan);
        return pile.debtOf(loan);
    }

    function seizure(uint loan) public {
        require(seizable(loan));
        shelf.free(loan, address(this));
    }

    function nftOwner(uint loan) public returns(address) {
        (address registry, uint256 tokenId, , ) = shelf.shelf(loan);
        return NFTLike(registry).ownerOf(tokenId);
    }

    function seizable(uint loan) public returns(bool) {
        uint price = nowPrice(loan);
        uint debt = nowDebt(loan);

        uint ratio = rdiv(price, debt);
        if(ratio >= threshold) {
            return false;
        }
        return true;
    }

    function collectable(uint loan) public returns(bool) {
        return nftOwner(loan) == address(this);
    }

    function free(uint loan, address usr) public auth {
        (address registry, uint256 tokenId, , ) = shelf.shelf(loan);
        NFTLike(registry).transferFrom(address(this), usr, tokenId);
    }
}
