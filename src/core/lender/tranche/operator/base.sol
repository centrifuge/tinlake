// Copyright (C) 2020 Centrifuge
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
    function supply(address usr, uint currencyAmount, uint tokenAmount) public;
    function redeem(address usr, uint currencyAmount, uint tokenAmount) public;
}

contract AssessorLike {
    function calcTokenPrice() public returns(uint);
}
// Abstract Contract
contract BaseOperator is DSNote, Math {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    TrancheLike public tranche;
    AssessorLike public assessor;

    constructor(address tranche_, address assessor_) internal {
        wards[msg.sender] = 1;
        tranche = TrancheLike(tranche);
        assessor = AssessorLike(assessor_);
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "tranche") { tranche = TrancheLike(addr); }
        else if (what == "assessor") { assessor = AssessorLike(addr); }
        else revert();
    }

    function _supply(uint currencyAmount) internal {
        tranche.supply(msg.sender, currencyAmount, rdiv(currencyAmount, assessor.calcTokenPrice()));

    }

    function _redeem(uint tokenAmount) internal {
        tranche.redeem(msg.sender, rmul(tokenAmount, assessor.calcTokenPrice()), tokenAmount);
    }
}