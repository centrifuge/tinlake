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

    function ActionTake() public returns (uint);
    function ActionGive() public returns (uint);
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
        (uint action, uint amount) = manager.requestAction();

        if (action == manager.ActionTake()) {
            borrowTranches(amount);
        }

        if (action == manager.ActionGive()) {
            repayTranches(amount);
        }
    }

    // -- Borrow Tranches ---
    function borrowTranches(uint requestCurrency) internal  {
        requestCurrency = borrow(manager.junior(), requestCurrency);

        if (requestCurrency > 0) {
            requestCurrency = borrow(manager.senior(), requestCurrency);
            return;
        }
        revert("request amount too high");
    }

    function borrow(address tranche, uint requestCurrency) internal returns(uint left) {
        OperatorLike tranche = OperatorLike(tranche);
        uint maxTranche = tranche.balance();
        uint take = maxTranche;
        if (maxTranche >= requestCurrency) {
            take = requestCurrency;
        }

        tranche.borrow(address(manager.pile()), take);
        return requestCurrency - take;
    }

    // -- Repay Tranches ---
    function repayTranches(uint availableCurrency) public auth {
        availableCurrency = repay(manager.senior(), availableCurrency);

        if (availableCurrency > 0) {
            // junior gets the rest
            OperatorLike(manager.junior()).repay(manager.pile(), availableCurrency);
        }
    }

    function repay(address tranche, uint availableCurrency) internal returns(uint left) {
        OperatorLike tranche = OperatorLike(tranche);
        uint give = tranche.debt();
        if (availableCurrency < tranche.debt()) {
            give = availableCurrency;
        }

        tranche.repay(address(manager.pile()), give);
        return availableCurrency - give;
    }
}
