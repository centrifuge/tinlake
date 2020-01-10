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

import "./operator.sol";

// RestrictedOperator restricts the allowance of users
// the allowanceActive flag actives the restriction
// openAccess by default deactivated
contract RestrictedOperator is Operator {

    bool public supplyActive;
    bool public redeemActive;

    struct Restriction {
        uint maxCurrency;   // uint(-1) unlimited access by convention
        uint maxToken;      // uint(-1) unlimited access by convention
    }

    mapping (address => Restriction) allowance;

    bool allowanceActive;

    constructor(address tranche_, address assessor_)
    Operator(tranche_, assessor_, false) public {
        supplyActive = true;
        redeemActive = true;
        allowanceActive = true;
    }

    function file(bytes32 what, bool value) public auth {
        if (what == "supplyActive") { supplyActive = value; }
        else if (what == "redeemActive") { redeemActive = value; }
        else if (what == "allowanceActive") { allowanceActive = value; }
        // openAccess by default always false
        else { revert(); }
    }

    function approve(address usr, uint maxToken, uint maxCurrency) public auth {
        if(wards[usr] == 0) {
            wards[usr] = UserAccess;
        }
        allowance[msg.sender].maxCurrency = maxCurrency;
        allowance[msg.sender].maxToken = maxToken;
    }

    function supply(uint currencyAmount) public auth_external {
        require(supplyActive);
        if (allowanceActive && allowance[msg.sender].maxCurrency != uint(-1)) {
            require(allowance[msg.sender].maxCurrency >= currencyAmount);
            allowance[msg.sender].maxCurrency = sub(allowance[msg.sender].maxCurrency, currencyAmount);
        }
        super.supply(currencyAmount);
    }

    function redeem(uint tokenAmount) public auth_external {
        require(redeemActive);
        if (allowanceActive && allowance[msg.sender].maxToken != uint(-1)) {
            require(allowance[msg.sender].maxToken >= tokenAmount);
            allowance[msg.sender].maxToken = sub(allowance[msg.sender].maxToken, tokenAmount);
        }
        super.redeem(tokenAmount);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
}
