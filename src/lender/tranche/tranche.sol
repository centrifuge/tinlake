// Copyright (C) 2020 Centrifuge
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

pragma solidity >=0.5.3;

import "ds-note/note.sol";
import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

contract TokenLike{
    function totalSupply() public returns (uint);
    function balanceOf(address) public returns (uint);
    function transferFrom(address,address,uint) public returns (bool);
    function approve(address, uint) public;
    function mint(address, uint) public;
    function burn(address, uint) public;
}

// Tranche
// Interface of a tranche. Coordinates investments and borrows to/from the tranche.
contract Tranche is DSNote, Auth {

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

    function balance() external returns (uint) {
        return currency.balanceOf(self);
    }

    function tokenSupply() external returns (uint) {
        return token.totalSupply();
    }

    // -- Lender Side --
    function supply(address usr, uint currencyAmount, uint tokenAmount) external note auth {
        require(currency.transferFrom(usr, self, currencyAmount), "currency-transfer-failed");
        token.mint(usr, tokenAmount);
    }

    function redeem(address usr, uint currencyAmount, uint tokenAmount) external note auth {
        require(token.transferFrom(usr, self, tokenAmount), "token-transfer-failed");
        token.burn(self, tokenAmount);
        require(currency.transferFrom(self, usr, currencyAmount), "currency-transfer-failed");
    }

    // -- Borrow Side --
    function repay(address usr, uint currencyAmount) public note auth {
        require(currency.transferFrom(usr, self, currencyAmount), "currency-transfer-failed");
    }

    function borrow(address usr, uint currencyAmount) public note auth {
        require(currency.transferFrom(self, usr, currencyAmount), "currency-transfer-failed");
    }
}
