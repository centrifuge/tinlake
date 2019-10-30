// valve.sol -- determines if CVT can be minted or not
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

contract ShelfLike {
    function bags() public returns (uint);
}
contract TokenLike {
    function mint(address, uint) public;
    function burn(address, uint) public;
    function totalSupply() public returns (uint);
    function balanceOf(address) public returns (uint);
}

// Valve
// Valve allows minting extra collateral value tokens if the total supply doesn't surpass the collateral value in the shelf or burning of tokens if the CVT price is above the 1/1 peg.
contract Valve {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike public tkn;
    ShelfLike public shelf;
    uint constant ONE = 1.0E18;

    constructor(address tkn_, address shelf_) public {
        wards[msg.sender] = 1;
        tkn = TokenLike(tkn_); 
        shelf = ShelfLike(shelf_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "shelf") { shelf = ShelfLike(addr); }
        else revert();
    }

    // --- Valve ---
    function balance(address usr) public auth {
        if (shelf.bags() >= tkn.totalSupply()) {
            mintMax(usr);
        } else {
            burnMax(usr);
        }
    }

    function want() public returns (int) {
    return int(shelf.bags() - tkn.totalSupply());
    }

    function mint(address usr, uint wad) public auth {
        require(tkn.totalSupply()+wad <= shelf.bags(), "over-supply");
        tkn.mint(usr, wad);
    }
    
    function mintMax(address usr) public auth {
        tkn.mint(usr, shelf.bags()-tkn.totalSupply());
    }

    function burnMax(address usr) public auth {
        uint wad = tkn.totalSupply()-shelf.bags(); // safemath
        uint avail = tkn.balanceOf(usr);
        if (avail < wad) {
            tkn.burn(usr, avail);
        } else {
            tkn.burn(usr, wad);
        }
    }
}
