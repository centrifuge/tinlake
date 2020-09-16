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
    function disburse(address usr) public returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken);
    function disburse(address usr, uint endEpoch) public returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken);
}

interface RestrictedTokenLike {
    function hasMember(address) external view returns (bool);
}

contract Operator is DSNote, Auth {
    TrancheLike public tranche;
    RestrictedTokenLike public token;
   
    constructor(address tranche_) public {
        wards[msg.sender] = 1;
        tranche = TrancheLike(tranche_);
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "tranche") { tranche = TrancheLike(addr); }
        else if (contractName == "token") { token = RestrictedTokenLike(addr); }
        else revert();
    }

    /// only investors that are on the memberlist can submit supplyOrders
    function supplyOrder(uint amount) public note {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        tranche.supplyOrder(msg.sender, amount);
    }

    /// only investors that are on the memberlist can submit redeemOrders
    function redeemOrder(uint amount) public note {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        token.hasMember(msg.sender);
        tranche.redeemOrder(msg.sender, amount);
    }

    /// only investors that are on the memberlist can disburse
    function disburse() external
        returns(uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken)
    {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        return tranche.disburse(msg.sender);
    }

    function disburse(uint endEpoch) external
        returns(uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken)
    {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        return tranche.disburse(msg.sender, endEpoch);
    }


}
