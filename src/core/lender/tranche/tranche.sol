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

pragma solidity >=0.5.12;

import "ds-note/note.sol";
import "ds-math/math.sol";

contract TokenLike{
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
    function mint(address, uint) public;
    function burn(address, uint) public;
}

// Tranche
// Interface of a tranche. Coordinates investments and borrows to/from the tranche.
contract Tranche is DSNote, DSMath {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike public currency;
    TokenLike public token;

    address public self;

    constructor(address token_, address currency_) public {
        wards[msg.sender] = 1;

        token = TokenLike(token_);
        currency = TokenLike(currency_);

        self = address(this);
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "currency") { currency = TokenLike(addr); }
        else if (what == "token") { token = TokenLike(addr); }
        else revert();
    }

    function balance() public returns (uint) {
        return currency.balanceOf(self);
    }

    function tokenSupply() public returns (uint) {
        return token.totalSupply();
    }

    // -- Lender Side --
    function supply(address usr, uint currencyAmount, uint tokenAmount) public note auth {
        currency.transferFrom(usr, self, currencyAmount);
        token.mint(usr, tokenAmount);
    }

    function redeem(address usr, uint currencyAmount, uint tokenAmount) public note auth {
        token.transferFrom(usr, self, tokenAmount);
        token.burn(self, tokenAmount);
        currency.transferFrom(self, usr, currencyAmount);
    }

    // -- Borrow Side --
    function repay(address usr, uint currencyAmount) public note auth {
        currency.transferFrom(usr, self, currencyAmount);
    }

    function borrow(address usr, uint currencyAmount) public note auth {
        currency.transferFrom(self, usr, currencyAmount);
    }
}
