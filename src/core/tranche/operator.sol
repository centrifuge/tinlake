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
import "ds-math/math.sol";

contract TokenLike{
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
    function mint(address, uint) public;
    function burn(address, uint) public;
}

contract AssessorLike {
    function getAssetValue() public returns(uint);
}

// Operator
// Interface of a tranche. Coordinates investments and borrows to/from the tranche.
contract Operator is DSNote, DSMath {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    bool public supplyActive;
    bool public redeemActive;
    
    // --- Data ---
    TokenLike public token;
    TokenLike public currency;

    AssessorLike public assessor;

    address public self;

    constructor(address token_, address currency_, address assessor_) public {
        wards[msg.sender] = 1;

        token = TokenLike(token_);
        currency = TokenLike(currency_);
        assessor = AssessorLike(assessor_);

        self = address(this);
        
        supplyActive = true;
        redeemActive = true;
    }

    function file(bytes32 what, bool data) public note auth {
        if (what == "supply") { supplyActive = data; }
        else if (what == "redeem") { redeemActive = data; }
    }
    
    function balance() public returns (uint) {
        return currency.balanceOf(self);
    }

    function tokenSupply() public returns (uint) {
        return token.totalSupply();
    }

    // -- Lender Side --
    
    function supply(address usr, uint currencyAmount) public note auth {
        require (supplyActive);
        uint tokenAmount = getSlice(currencyAmount);
        supplyTransfers(usr, tokenAmount, currencyAmount);
    }

    function supplyTransfers(address usr, uint tokenAmount, uint currencyAmount) internal {
        currency.transferFrom(usr, self, currencyAmount);
        token.mint(usr, tokenAmount);
    }

    function redeem(address usr, uint tokenAmount) public note auth {
        require (redeemActive);
        uint slice = token.balanceOf(usr);
         if (slice < tokenAmount) {
            tokenAmount = slice;
        }
        uint currencyAmount = getPayout(tokenAmount);
        redeemTransfers(usr, tokenAmount, currencyAmount);
    }

    function redeemTransfers(address usr, uint tokenAmount, uint currencyAmount) internal {
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

    // -- Slice & Payouts --
    function getSlice(uint currencyAmount) internal returns (uint) {
        return rdiv(currencyAmount, getTokenPrice());
    }

    function getPayout(uint tokenAmount) internal returns (uint) {
        return rmul(tokenAmount, getTokenPrice());
    }

    function getTokenPrice() internal returns (uint) {
        return rdiv(assessor.getAssetValue(), tokenSupply());
    }
}
