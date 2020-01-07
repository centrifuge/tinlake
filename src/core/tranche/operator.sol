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

contract ReserveLike{
    function balance() public view returns (uint);
    function tokenBalanceOf(address) public view returns (uint);
    function redeem(address, uint, uint) public;
    function supply(address, uint, uint) public;
    function repay(address, uint) public;
    function borrow(address, uint) public;
}

contract SlicerLike {
   function getSlice(uint) public returns(uint);
   function getPayout(uint) public returns(uint);
}

// Operator
// Interface of a tranche. Coordinates investments and borrows to/from the tranche.
contract Operator is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    ReserveLike public reserve;
    SlicerLike public slicer;

    bool public supplyActive;
    bool public redeemActive;

    constructor(address reserve_, address slicer_) public {
        wards[msg.sender] = 1;
        slicer = SlicerLike(slicer_);
        reserve = ReserveLike(reserve_);
        supplyActive = true;
        redeemActive = true;
    }

    function file(bytes32 what, bool data) public note auth {
        if (what == "supply") { supplyActive = data; }
        else if (what == "redeem") { redeemActive = data; }
    }
    
    function balance() public returns (uint) {
        return reserve.balance();
    }

    function supply(address usr, uint currencyAmount) public note auth {
        require (supplyActive);
        uint tokenAmount = slicer.getSlice(currencyAmount);
        reserve.supply(usr, tokenAmount, currencyAmount);
    }

    function redeem(address usr, uint tokenAmount) public note auth {
        require (redeemActive);
        uint slice = reserve.tokenBalanceOf(usr); 
         if (slice < tokenAmount) {
            tokenAmount = slice;
        }
        uint currencyAmount = slicer.getPayout(tokenAmount);
        reserve.redeem(usr, tokenAmount, currencyAmount);
    }

    function repay(address usr, uint currencyAmount) public note auth {
        reserve.repay(usr, currencyAmount);
    }

    function borrow(address usr, uint currencyAmount) public note auth {
        reserve.borrow(usr, currencyAmount);
    }
}
