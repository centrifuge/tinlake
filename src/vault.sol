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

import "./lightswitch.sol";

contract PileLike {
    function want() public returns (int);
}

contract TokenLike {
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
}


// Vault serves as an interface to manage the lending actions of Tinlake.
contract Vault is Switchable {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    PileLike public pile;
    TokenLike public tkn;

    constructor (address pile_, address tkn_, address lightswitch_) Switchable(lightswitch_) public {
        wards[msg.sender] = 1;

        pile = PileLike(pile_);
        tkn = TokenLike(tkn_);
    }

    // --- Vault ---
    function balance() public auth {
        int want = pile.want();
        address self = address(this);
        uint wad;
        if (want > 0) {
            wad = uint(want);
            require(tkn.balanceOf(self) >= wad);
            tkn.transferFrom(self, address(pile), wad);
            return;

        }
        wad = uint(want *-1);
        require(tkn.balanceOf(address(pile)) >= wad);
        tkn.transferFrom(address(pile),self, wad);
    }

    function withdraw(address usr, uint wad) public auth  {
        address self = address(this);
        require(tkn.balanceOf(address(this)) >= wad);
        tkn.transferFrom(self, usr, wad);
    }
}