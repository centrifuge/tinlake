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
// Currency & Token amounts are denominated in wad
contract Reserve is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike public token;
    TokenLike public currency;

    constructor(address token_, address currency_) public {
        wards[msg.sender] = 1;
        token = TokenLike(token_);
        currency = TokenLike(currency_);
    }

    function balance() public returns (uint){
        return currency.balanceOf(address(this));
    }

    function sliceOf(address usr) public returns (uint) {
        return token.balanceOf(address(usr));
    }
    
    function supply(address usr, uint tokenAmount, uint currencyAmount) public note auth {
        currency.transferFrom(usr, address(this), currencyAmount);
        token.mint(usr, tokenAmount);
    }

    function redeem(address usr, uint tokenAmount, uint currencyAmount) public note auth {
        token.transferFrom(usr, address(this), tokenAmount);
        token.burn(address(this), tokenAmount);
        currency.transferFrom(address(this), usr, currencyAmount);
    }

    function repay(address usr, uint currencyAmount) public note auth {
        currency.transferFrom(usr, address(this), currencyAmount);
    }

    function borrow(address usr, uint currencyAmount) public note auth {
        currency.transferFrom(address(this), usr, currencyAmount);
    }
}
