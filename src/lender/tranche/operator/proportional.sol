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

    // expressed relative to totalCurrencyReturned
    mapping (address => uint) public currencyRedeemed;

    // expressed relative to totalPrincipalReturned
    mapping (address => uint) public principalRedeemed;


    bool public supplyAllowed  = true;
    uint public totalCurrencyReturned;
    uint public totalPrincipalReturned;
    uint public totalTrancheVolume;

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
            if(supplyAllowed_ == false) {
                // requires an initial token price of ONE
                totalTrancheVolume = tranche.tokenSupply();
            }
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
        tranche.supply(msg.sender, currencyAmount, rdiv(currencyAmount, ONE));
        distributor.balance();
    }

    /// redeem is proportional always allowed if loans are returned
    function redeem(uint tokenAmount) external  note {
        distributor.balance();
        uint currencyAmount = rmul(tokenAmount, assessor.calcAndUpdateTokenPrice(address(tranche)));
        require(assessor.redeemApprove(address(tranche), currencyAmount), "redeem-not-approved");
        tranche.redeem(msg.sender, currencyAmount, tokenAmount);
    }

    function calcMaxRedeemToken(address usr) public view returns(uint) {
        if (supplyAllowed) {
            return 0;
        }
        uint previouslyRedeemed = rmul(rdiv(principalRedeemed[usr], totalPrincipalReturned),supplyMaximum[usr]);
        uint maxRedeemToken = rmul(rdiv(totalPrincipalReturned, totalTrancheVolume), supplyMaximum[usr]);
        return safeSub(maxRedeemToken, previouslyRedeemed);
    }

    function calcRedeemCurrencyAmount(address usr,uint tokenAmount) public {

    }
}
