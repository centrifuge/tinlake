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

contract TrancheLike {
    function borrow(address, uint) public;
    function debt() public returns (uint);
    function repay(address, uint) public;
    function balance() public returns (uint);
}

contract ShelfLike {
    function ActionBorrow() public returns (uint);
    function ActionRepay() public returns (uint);
    function requestAction() public returns (uint, uint);
}

contract Distributor is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    address public shelf;

    // --- Tranches ---
    address public senior;
    address public junior;

    constructor(address shelf_)  public {
        wards[msg.sender] = 1;
        shelf = shelf_;
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "shelf") { shelf = addr; }
        if (what == "junior") { junior = addr; }
        else if (what == "senior") { senior = addr;}
        else revert();
    }

    function balance() public {
        (uint action, uint currencyAmount) = ShelfLike(shelf).requestAction();

        if (action == ShelfLike(shelf).ActionBorrow()) {
            borrowTranches(currencyAmount);
        }

        if (action == ShelfLike(shelf).ActionRepay()) {
            repayTranches(currencyAmount);
        }
    }

    // -- Borrow Tranches ---
    function borrowTranches(uint currencyAmount) internal  {
        currencyAmount = currencyAmount - borrow(junior, currencyAmount);

        if (currencyAmount > 0) {
            currencyAmount = currencyAmount - borrow(senior, currencyAmount);
        }

        if (currencyAmount > 0) {
            revert("requested currency amount too high");
        }
    }

    function borrow(address tranche, uint currencyAmount) internal returns(uint) {
        TrancheLike tranche = TrancheLike(tranche);

        uint available = tranche.balance();
        if (currencyAmount > available) {
            currencyAmount = available;
        }

        tranche.borrow(shelf, currencyAmount);
        return currencyAmount;
    }

    //  method      repayTranches
    //  available   total available currency for repaying the tranches
    function repayTranches(uint available) public auth {
        available = available - repay(senior, available);

        if (available > 0) {
            // junior gets the rest
            TrancheLike(junior).repay(shelf, available);
        }
    }

    /// repays the debt of a single tranche if enough currency is available
    /// @param `tranche` address of the tranche contract
    /// @param `available` total available currency to repay a tranche
    /// @return repaid currencyAmount
    /// @dev `available` and `currencyAmount` denominated in WAD (10^18)
    function repay(address tranche, uint available) internal returns(uint) {
        TrancheLike tranche = TrancheLike(tranche);
        uint currencyAmount = tranche.debt();
        if (available < currencyAmount) {
            currencyAmount = available;
        }

        tranche.repay(shelf, currencyAmount);
        return currencyAmount;
    }
}
