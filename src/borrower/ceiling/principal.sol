// principal.sol
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

// Principal is an implementation of the Ceiling module that defines the max amount a user can borrow.
// The principal of each loan is decreased with borrow transactions. Accrued interest is ignored.
contract Principal is DSNote, Auth, Math {
    mapping (uint => uint) public ceiling;

    constructor() public {
        wards[msg.sender] = 1;
    }


    function file(bytes32 what, uint loan, uint principal) external note auth {
        if (what == "loan") {
            ceiling[loan] = principal;
        } else revert("unknown parameter");

    }

    /// reverts if loan amount is higher than ceiling
    function borrow(uint loan, uint amount) external auth {
        // safeSub will revert if the ceiling[loan] < amount
        ceiling[loan] = safeSub(ceiling[loan], amount);
    }

    /// repay interface method not required for ceiling implementation
    function repay(uint loan, uint amount) external auth {
    }
}
