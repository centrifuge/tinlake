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

pragma solidity >=0.5.15 <0.6.0;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";

contract PileLike {
    function total() public view returns(uint);
}

contract PricePool is Auth, Math {
    uint public riskScore;
    PileLike pile;
    constructor() public {
        wards[msg.sender] = 1;
        riskScore = ONE;
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "pile") { pile = PileLike(addr); }
        else revert();
    }

    function file(bytes32 what, uint value) public auth {
        if(what == "riskscore") { riskScore = value;}
        else revert();
    }

    function totalValue() public view returns (uint) {
        return rmul(pile.total(), riskScore);
    }
}
