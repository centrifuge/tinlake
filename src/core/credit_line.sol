// store.sol
// Copyright (C) 2019 Centrifuge

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
pragma experimental ABIEncoderV2;

import "ds-note/note.sol";
import { DebtLike } from "./debt_register.sol";

contract CreditLine is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    DebtLike public debt;  
    mapping (uint =>  uint) public lines;

    constructor() public {
        wards[msg.sender] = 1;
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "debt") { debt = DebtLike(addr); }
        else revert();
    }

    function file(uint loan, uint creditLine) public note auth {
        lines[loan] = creditLine;
    }

    function borrow(uint loan, uint currencyAmount) public note auth {
        require(lines[loan] >= add(debt.debt(loan)+currencyAmount));
    }
}
