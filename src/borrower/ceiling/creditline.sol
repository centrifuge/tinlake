// cerditline.sol
// Copyright (C) 2020 Centrifuge

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

contract PileLike {
    uint public total;
    function debt(uint) public returns (uint);
    function accrue(uint) public;
    function incDebt(uint, uint) public;
    function decDebt(uint, uint) public;
}

// CreditLine is an implementation of the Ceiling module that defines the max amount a user can borrow.
// Borrowers can always repay and borrow new money as long as the total borrowed amount stays under the defined line of credit. Accrued interest is considered.
contract CreditLine is DSNote, Auth, Math {

    // --- Data ---
    PileLike pile;  
    mapping (uint =>  uint) public values;

    constructor(address pile_) public {
        pile = PileLike(pile_);
        wards[msg.sender] = 1;
    }

    function ceiling(uint loan) external returns(uint) {
        if (values[loan] > pile.debt(loan)) {
            return safeSub(values[loan], pile.debt(loan));
        } 
        return 0;
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) external note auth {
        if (contractName == "pile") { pile = PileLike(addr); }
        else revert();
    }

    function file(bytes32 what, uint loan, uint creditLine) external note auth {
        if(what == "loan") {
            values[loan] = creditLine;
        } else revert("unknown parameter");

    }

    /// borrow checks if loan amount would violate the loan ceiling
    function borrow(uint loan, uint amount) external auth {
        // ceiling check uses existing loan debt
        require(values[loan] >= safeAdd(pile.debt(loan), amount), "borrow-amount-too-high");
    }

    function repay(uint loan, uint amount) external auth {}
}
