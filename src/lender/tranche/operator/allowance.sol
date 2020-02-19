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

pragma solidity >=0.5.3;

import "./base.sol";

// AllowanceOperator sets allowances for investors
contract AllowanceOperator is BaseOperator {
    mapping (address => uint) public maxCurrency;  // uint(-1) unlimited access by convention
    mapping (address => uint) public maxToken;     // uint(-1) unlimited access by convention

    constructor(address tranche_, address assessor_, address distributor_)
    BaseOperator(tranche_, assessor_, distributor_) public {}

    function approve(address usr, uint maxCurrency_, uint maxToken_) external auth {
        maxCurrency[usr] = maxCurrency_;
        maxToken[usr] = maxToken_;
    }

    function supply(uint currencyAmount) external {
        if (maxCurrency[msg.sender] != uint(-1)) {
            require(maxCurrency[msg.sender] >= currencyAmount);
            maxCurrency[msg.sender] = safeSub(maxCurrency[msg.sender], currencyAmount);
        }
        _supply(currencyAmount);
    }

    function redeem(uint tokenAmount) external {
        if (maxToken[msg.sender] != uint(-1)) {
            require(maxToken[msg.sender] >= tokenAmount);
            maxToken[msg.sender] = safeSub(maxToken[msg.sender], tokenAmount);
        }
        _redeem(tokenAmount);
    }
}
