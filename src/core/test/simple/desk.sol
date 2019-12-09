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

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
}

contract PileLike {
    function want() public returns (int);
}

contract Desk {

    // --- Data ---
    PileLike public pile;
    // simple tranche manager = 1 tranche/1 operator for now
    TokenLike public token;
    constructor (address pile_, address token_) public {
        pile = PileLike(pile_);
        token = TokenLike(token_);
    }

    // --- Calls ---

    function depend(bytes32 what, address addr) public {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "token") { token = TokenLike(addr); }
        else revert();
    }

    function balance() public {
        int wad = pile.want();
        if (wad > 0) {
            take(address(pile), uint(wad));
        } else {
            give(address(pile), uint(wad*-1));
        }
    }

    function take(address pile_, uint wad) public {
        token.mint(pile_, wad);
    }

    function give(address pile_, uint wad) internal {
        token.transferFrom(pile_, address(this), wad);
    }
}
