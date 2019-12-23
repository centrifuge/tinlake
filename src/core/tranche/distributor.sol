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

contract PileLike {
    function want() public returns (int);
}

contract OperatorLike {
    function borrow(address, uint) public;
    function debt() public returns (uint);
    function repay(address, uint) public;
    function balance() public returns (uint);
    function file(bytes32, bool) public;
}

contract ManagerLike {
    struct Tranche {
        uint ratio;
        OperatorLike operator;
    }

    Tranche[] public tranches;
    PileLike public pile;

    bool public poolClosing;

    function ratioOf(uint) public returns (uint);
    function checkPile() public returns (int);
    function trancheCount() public returns (uint);
    function operatorOf(uint i) public returns (address);
}

contract Distributor is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    ManagerLike public manager;

    constructor(address manager_) public {
        wards[msg.sender] = 1;
        manager = ManagerLike(manager_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "manager") { manager = ManagerLike(addr); }
        else revert();
    }

    function repayTranches(uint availableCurrency) public auth {
        for (uint i = manager.trancheCount() - 1; i >= 0; i--) {
            OperatorLike o = OperatorLike(manager.operatorOf(i));
            uint trancheDebt = o.debt();
            if (trancheDebt >= availableCurrency) {
                o.repay(address(manager.pile), availableCurrency);
                return;
            }
            o.repay(address(manager.pile), trancheDebt);
            availableCurrency = availableCurrency - trancheDebt;
        }
    }
}
