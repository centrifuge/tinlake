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
import "tinlake-math/math.sol";

contract TrancheLike {
    function borrow(address, uint) public;
    function debt() public returns (uint);
    function repay(address, uint) public;
    function balance() public returns (uint);
}

contract ShelfLike {
    function balanceRequest() public returns (bool requestWant, uint amount);
}

contract Distributor is DSNote, Math {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    ShelfLike public shelf;

    // --- Tranches ---
    TrancheLike public senior;
    TrancheLike public junior;

    constructor(address shelf_)  public {
        wards[msg.sender] = 1;
        shelf = ShelfLike(shelf_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "shelf") { shelf = ShelfLike(addr); }
        if (what == "junior") { junior = TrancheLike(addr); }
        else if (what == "senior") { senior = TrancheLike(addr); }
        else revert();
    }

    function balance() public {
        (bool requestWant, uint currencyAmount) = shelf.balanceRequest();

        if (requestWant) {
            borrowTranches(currencyAmount);
            return;
        }

        repayTranches(currencyAmount);
    }

    // -- Borrow Tranches ---
    function borrowTranches(uint currencyAmount) internal  {
        currencyAmount = sub(currencyAmount, borrow(junior, currencyAmount));

        if (currencyAmount > 0) {
            currencyAmount = currencyAmount - borrow(senior, currencyAmount);
        }

        if (currencyAmount > 0) {
            revert("requested currency amount too high");
        }
    }

    function borrow(TrancheLike tranche, uint currencyAmount) internal returns(uint) {
        uint available = tranche.balance();
        if (currencyAmount > available) {
            currencyAmount = available;
        }

        tranche.borrow(address(shelf), currencyAmount);
        return currencyAmount;
    }

    //  method      repayTranches
    //  available   total available currency for repaying the tranches
    function repayTranches(uint available) public auth {
        available = sub(available, repay(senior, available));

        if (available > 0) {
            // junior gets the rest
            junior.repay(address(shelf), available);
        }
    }

    /// repays the debt of a single tranche if enough currency is available
    /// @param `tranche` address of the tranche contract
    /// @param `available` total available currency to repay a tranche
    /// @return repaid currencyAmount
    /// @dev `available` and `currencyAmount` denominated in WAD (10^18)
    function repay(TrancheLike tranche, uint available) internal returns(uint) {
        uint currencyAmount = tranche.debt();
        if (available < currencyAmount) {
            currencyAmount = available;
        }

        tranche.repay(address(shelf), currencyAmount);
        return currencyAmount;
    }
}
