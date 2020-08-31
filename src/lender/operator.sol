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

pragma solidity >=0.5.15 <0.6.0;

import "ds-note/note.sol";
import "tinlake-auth/auth.sol";

contract TrancheLike {
    function supplyOrder(address usr, uint currencyAmount) public;
    function redeemOrder(address usr, uint tokenAmount) public;
    function disburse(address usr) public;
}

contract Operator is DSNote, Auth {
    TrancheLike public tranche;

    // -- Investors --
    mapping (address => uint) public investors;
    function relyInvestor(address usr) public auth note { investors[usr] = 1; }
    function denyInvestor(address usr) public auth note { investors[usr] = 0; }
    modifier auth_investor { require(investors[msg.sender] == 1); _; }

    constructor(address tranche_) public {
        wards[msg.sender] = 1;
        tranche = TrancheLike(tranche_);
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "tranche") { tranche = TrancheLike(addr); }
        else revert();
    }

    /// only investors that are on the memberlist can submit supplyOrders
    function supplyOrder(uint amount) public auth_investor note {
        tranche.supplyOrder(msg.sender, amount);
    }

    /// only investors that are on the memberlist can submit redeemOrders
    function redeemOrder(uint amount) public auth_investor note {
        tranche.redeemOrder(msg.sender, amount);
    }

    /// only investors that are on the memberlist can disburse
    function disburse() external auth_investor note {
        tranche.disburse(msg.sender);
    }
}
