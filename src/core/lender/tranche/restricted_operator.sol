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

contract RestrictedOperator is Operator {

    bool public supplyActive;
    bool public redeemActive;

    struct Restriction {
        uint maxCurrency;
        uint maxToken;
    }

    mapping (address => Restriction) allowance;

    constructor(address tranche_, address assessor_, bool openAccess_)
    Operator(tranche_,assessor_,openAccess_) public {
        supplyActive = true;
        redeemActive = true;
    }

    function file(bytes32 what, bool value) public auth {
        if (what == "supplyActive") { supplyActive = value; }
        else if (what == "redeemActive") { redeemActive = value; }
        else super.file(what, value);
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
        if (allowance[msg.sender].maxCurrency != uint(-1)) {
            require(allowance[msg.sender].maxCurrency >= currencyAmount);
            allowance[msg.sender].maxCurrency = sub(allowance[msg.sender].maxCurrency, currencyAmount);
        }
        super.supply(currencyAmount);
    }

    function redeem(uint tokenAmount) public auth_external {
        require(redeemActive);
        if (allowance[msg.sender].maxToken != uint(-1)) {
            require(allowance[msg.sender].maxToken >= tokenAmount);
            allowance[msg.sender].maxToken = sub(allowance[msg.sender].maxToken, tokenAmount);
        }
        super.redeem(tokenAmount);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
}
