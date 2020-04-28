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
import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

contract TrancheLike {
    function supply(address usr, uint currencyAmount, uint tokenAmount) public;
    function redeem(address usr, uint currencyAmount, uint tokenAmount) public;
    function tokenSupply() public returns (uint);
}

contract AssessorLike {
    function calcAndUpdateTokenPrice(address tranche) public returns(uint);
    function supplyApprove(address tranche, uint currencyAmount) public returns(bool);
    function redeemApprove(address tranche, uint currencyAmount) public returns(bool);
    function tokenAmountForONE() public returns(uint);
}

contract DistributorLike {
    function balance() public;
}

contract ProportionalOperator is Math, DSNote, Auth  {
    TrancheLike public tranche;
    AssessorLike public assessor;
    DistributorLike public distributor;

    // lender mappings
    // each value in a own map for gas-optimization
    mapping (address => uint) public supplyMaximum;
    mapping (address => uint) public currentSupplyLimit;
    // helper we could also calculate it
    mapping (address => uint) public tokenRedeemed;

    // expressed in totalCurrencyReturned notation
    mapping (address => uint) public currencyRedeemed;

    // expressed in totalPrincipalReturned notation
    mapping (address => uint) public principalRedeemed;

    bool public supplyAllowed  = true;

    // denominated in currency
    uint public totalCurrencyReturned;

    // denominated in currency
    uint public totalPrincipalReturned;

    // denominated in currency
    uint public totalPrincipal;

    constructor(address tranche_, address assessor_, address distributor_) public {
        wards[msg.sender] = 1;
        tranche = TrancheLike(tranche_);
        assessor = AssessorLike(assessor_);
        distributor = DistributorLike(distributor_);
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "tranche") { tranche = TrancheLike(addr); }
        else if (contractName == "assessor") { assessor = AssessorLike(addr); }
        else if (contractName == "distributor") { distributor = DistributorLike(addr); }
        else revert();
    }

    function file(bytes32 what, bool supplyAllowed_) public auth {
        if(what == "supplyAllowed") {
            supplyAllowed = supplyAllowed_;
        }
    }

    function updateReturned(uint currencyReturned, uint principalReturned) public auth {
        totalCurrencyReturned += currencyReturned;
        totalPrincipalReturned += principalReturned;
    }

    /// defines the max amount of currency for supply
    function approve(address usr, uint currencyAmount) external auth {
        supplyMaximum[usr] = currencyAmount;
        currentSupplyLimit[usr] = currencyAmount;
    }

    /// only approved investors can supply and approved
    function supply(uint currencyAmount) external note {
        require(supplyAllowed);

        require(currentSupplyLimit[msg.sender] >= currencyAmount, "not-enough-currency");
        currentSupplyLimit[msg.sender] = safeSub(currentSupplyLimit[msg.sender], currencyAmount);

        require(assessor.supplyApprove(address(tranche), currencyAmount), "supply-not-approved");

        // pre-defined tokenPrice of ONE
        uint tokenAmount = rdiv(currencyAmount, ONE);
        tranche.supply(msg.sender, currencyAmount, tokenAmount);

        // todo we don't need the variable if first loan starts after all investors supplied
        // instead tranche.balance could be used
        totalPrincipal = safeAdd(totalPrincipal, currencyAmount);

        distributor.balance();
    }

    /// redeem is proportional allowed
    function redeem(uint tokenAmount) external note {
        distributor.balance();
        (uint currencyAmount, uint currencyRedeemed_,uint  principalRedeemed_) = calcRedeemCurrencyAmount(msg.sender, tokenAmount);
        currencyRedeemed[msg.sender] = currencyRedeemed_;
        principalRedeemed[msg.sender] = principalRedeemed_;
        require(assessor.redeemApprove(address(tranche), currencyAmount), "redeem-not-approved");
        tokenRedeemed[msg.sender] = safeAdd(tokenRedeemed[msg.sender], tokenAmount);
        tranche.redeem(msg.sender, currencyAmount, tokenAmount);
    }

    /// calculates the current max amount of tokens a user can redeem
    /// the max amount of token depends on the total principal returned
    /// and previous redeem actions of the user
    function calcMaxRedeemToken(address usr) public view returns(uint) {
        if (supplyAllowed) {
            return 0;
        }

        // considers the case if a user didn't supply the maximum amount possible
        uint maxRedeemToken = rmul(rdiv(totalPrincipalReturned, totalPrincipal), safeSub(supplyMaximum[usr], currentSupplyLimit[usr]));

        return safeSub(maxRedeemToken, tokenRedeemed[usr]);
    }

    /// calculates the amount of currency a user can redeem for a specific token amount
    /// the used token price for the conversion can be different among users depending on their
    /// redeem history.
    function calcRedeemCurrencyAmount(address usr, uint tokenAmount) public view returns(uint, uint, uint) {
        // solidity gas-optimized calculation avoiding local variable if possible

        uint maxTokenAmount = calcMaxRedeemToken(usr);
        require(tokenAmount <= maxTokenAmount, "tokenAmount higher than maximum");

        uint redeemRatio = rdiv(tokenAmount, maxTokenAmount);

        // c is the delta between total currency returned and the portion the user has redeemed of it.
        uint c = safeSub(totalCurrencyReturned, currencyRedeemed[usr]);

        // p is the delta between total currency returned and the portion the user has redeemed of it.
        uint p = safeSub(totalPrincipalReturned, principalRedeemed[usr]);

        return (
        // calculates currencyAmount by multiplying the tokenAmount with the tokenPrice
        rmul(tokenAmount, rdiv(c, p)),

        // updated currencyRedeemed of the user
        safeAdd(rmul(c, redeemRatio), currencyRedeemed[usr]),

        // updated principalRedeemed of the user
        safeAdd(rmul(p, redeemRatio), principalRedeemed[usr])
        );
    }


}
