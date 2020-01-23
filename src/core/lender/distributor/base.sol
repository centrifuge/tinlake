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
import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

/// Interfaces
contract TrancheLike {
    function borrow(address, uint) public;
    function debt() public returns (uint);
    function repay(address, uint) public;
    function balance() public returns (uint);
}

contract ShelfLike {
    function balanceRequest() public returns (bool requestWant, uint amount);
}

contract CurrencyLike {
    function transferFrom(address from, address to, uint amount) public;
    function balanceOf(address) public returns(uint);
    function approve(address, uint) public;
}


/// The Distributor contract borrows and repays from tranches
/// In the base implementation the requested `currencyAmount` always is taken from the
/// junior tranche first. For repayment senior comes first.
/// This implementation can handle one or two tranches.
contract BaseDistributor is Math, DSNote, Auth {

    ShelfLike public shelf;

    // --- Tranches ---
    TrancheLike public senior;
    TrancheLike public junior;

    CurrencyLike public currency;

    constructor(address currency_) public {
        wards[msg.sender] = 1;
        currency = CurrencyLike(currency_);

    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "shelf") { shelf = ShelfLike(addr); }
        else if (what == "junior") { junior = TrancheLike(addr); }
        else if (what == "senior") { senior = TrancheLike(addr); }
        else if (what == "currency") { currency = CurrencyLike(addr); }
        else revert();
    }

    /// moves balance from junior tranche to senior.
    /// if senior tranche has a debt.
    function _balanceTranches() internal {
        if(address(senior) == address(0)) {
            return;
        }

        uint seniorDebt = senior.debt();
        uint juniorBalance = junior.balance();
        if(juniorBalance > 0 && seniorDebt > 0) {
            uint amount = seniorDebt;
            if (amount > juniorBalance) {
                amount = juniorBalance;
            }
            // move junior reserve to distributor -> senior
            // using the borrow method due to allowance permissions
            junior.borrow(address(this), amount);
            currency.approve(address(senior), amount);
            senior.repay(address(this), amount);
        }
    }

    /// handles requests from the shelf contract (borrower side)
    function balance() public {
        _balanceTranches();

        (bool requestWant, uint currencyAmount) = shelf.balanceRequest();

        if (requestWant) {
            _borrowTranches(currencyAmount);
            return;
        }

        _repayTranches(currencyAmount);
    }

    /// borrows currency from the tranches.
    /// @param currencyAmount request amount to borrow
    /// @dev currencyAmount denominated in WAD (10^18)
    function _borrowTranches(uint currencyAmount) internal  {
        uint totalAmount = currencyAmount;
        if(currencyAmount == 0) {
            return;
        }

        // take from junior first
        currencyAmount = sub(currencyAmount, _borrow(junior, currencyAmount));

        if (currencyAmount > 0 && address(senior) != address(0)) {
            currencyAmount = sub(currencyAmount, _borrow(senior, currencyAmount));
        }

        if (currencyAmount > 0) {
            revert("requested currency amount too high");
        }

        // distributor -> shelf
        currency.transferFrom(address(this), address(shelf), totalAmount);
    }

    /// borrows up to the max amount from one tranche
    /// @param tranche reference to the tranche contract
    /// @param currencyAmount request amount to borrow
    /// @return actual borrowed currencyAmount
    /// @dev currencyAmount denominated in WAD (10^18)
    function _borrow(TrancheLike tranche, uint currencyAmount) internal returns(uint) {
        uint available = tranche.balance();
        if (currencyAmount > available) {
            currencyAmount = available;
        }

        tranche.borrow(address(this), currencyAmount);
        return currencyAmount;
    }

    /// repays according to a waterfall model
    /// @param available total available currency to repay the tranches
    /// @dev available denominated in WAD (10^18)
    function _repayTranches(uint available) internal {
        if(available == 0) {
            return;
        }

        // shelf -> distributor
        currency.transferFrom(address(shelf), address(this), available);

        // repay senior always first
        if(address(senior) != address(0)) {
            available = sub(available, _repay(senior, available));
        }

        if (available > 0) {
            // junior gets the rest
            currency.approve(address(junior), available);
            junior.repay(address(this), available);
        }
    }

    /// repays the debt of a single tranche if enough currency is available
    /// @param tranche address of the tranche contract
    /// @param available total available currency to repay a tranche
    /// @return actual repaid currencyAmount
    /// @dev available and currency Amount denominated in WAD (10^18)
    function _repay(TrancheLike tranche, uint available) internal returns(uint) {
        uint currencyAmount = tranche.debt();
        if (available < currencyAmount) {
            currencyAmount = available;
        }
        if (currencyAmount > 0) {
            currency.approve(address(senior), currencyAmount);
            tranche.repay(address(this), currencyAmount);
        }
        return currencyAmount;
    }
}
