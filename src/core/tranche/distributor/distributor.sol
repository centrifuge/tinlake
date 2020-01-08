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

contract OperatorLike {
    function borrow(address, uint) public;
    function debt() public returns (uint);
    function repay(address, uint) public;
    function balance() public returns (uint);
}

contract ManagerLike {
    function senior() public returns(address);
    function junior() public returns(address);

    function pile() public returns(address);
    function poolClosing() public returns(bool);

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

    ManagerLike public manager;

    constructor(address manager_)  public {
        wards[msg.sender] = 1;
        manager = ManagerLike(manager_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "manager") { manager = ManagerLike(addr); }
        else revert();
    }

    function balance() public {
        (uint action, uint currencyAmount) = manager.requestAction();

        if (action == manager.ActionBorrow()) {
            borrowTranches(currencyAmount);
        }

        if (action == manager.ActionRepay()) {
            repayTranches(currencyAmount);
        }
    }

    // -- Borrow Tranches ---
    function borrowTranches(uint currencyAmount) internal  {
        currencyAmount = currencyAmount - borrow(manager.junior(), currencyAmount);

        if (currencyAmount > 0) {
            currencyAmount = currencyAmount - borrow(manager.senior(), currencyAmount);
        }

        if (currencyAmount > 0) {
            revert("requested currency amount too high");
        }
    }

    function borrow(address tranche, uint currencyAmount) internal returns(uint) {
        OperatorLike tranche = OperatorLike(tranche);

        uint available = tranche.balance();
        if (currencyAmount > available) {
            currencyAmount = available;
        }

        tranche.borrow(address(manager.pile()), currencyAmount);
        return currencyAmount;
    }

    //  method      repayTranches
    //  available   total available currency for repaying the tranches
    function repayTranches(uint available) public auth {
        available = available - repay(manager.senior(), available);

        if (available > 0) {
            // junior gets the rest
            OperatorLike(manager.junior()).repay(manager.pile(), available);
        }
    }


    /// repays the debt of a single tranche if enough currency is available
    /// @param `tranche` address of the tranche contract
    /// @param `available` total available currency to repay a tranche
    /// @return repaid currencyAmount
    /// @dev `available` and `currencyAmount` denominated in WAD (10^18)
    function repay(address tranche, uint available) internal returns(uint) {
        OperatorLike tranche = OperatorLike(tranche);
        uint currencyAmount = tranche.debt();
        if (available < currencyAmount) {
            currencyAmount = available;
        }

        tranche.repay(address(manager.pile()), currencyAmount);
        return currencyAmount;
    }
}
