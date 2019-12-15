// Copyright (C) 2019 Centrifuge
//
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

import "ds-note/note.sol";

contract TokenLike{
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
    function mint(address, uint) public;
    function burn(address, uint) public;
}

// Reserve
// Manages the token balances & transfers
contract Reserve is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike public sliceTkn;
    TokenLike public tkn;

    constructor(address sliceTkn_, address tkn_) public {
        wards[msg.sender] = 1;
        sliceTkn = TokenLike(sliceTkn_);
        tkn = TokenLike(tkn_);
    }

    function balance() public returns (uint){
        return tkn.balanceOf(address(this));
    }

    function sliceOf(address usr) public returns (uint) {
        return sliceTkn.balanceOf(address(usr));
    }
    
    function supply(address usr, uint wadS, uint wadT) public note auth {
        tkn.transferFrom(usr, address(this), wadT);
        sliceTkn.mint(usr, wadS);
    }

    function redeem(address usr, uint wadS, uint wadT) public note auth {
        sliceTkn.burn(usr, wadS);
        tkn.transferFrom(address(this), usr, wadT);
    }

    function give(address usr, uint wadT) public note auth {
        tkn.transferFrom(usr, address(this), wadT);
    }

    function take(address usr, uint wadT) public note auth {
        tkn.transferFrom(address(this), usr, wadT);
    }
}
