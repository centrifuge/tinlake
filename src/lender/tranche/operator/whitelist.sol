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

contract WhitelistOperator is BaseOperator {

    // -- Wards --
    // - RootAdmin contract for rely/deny investors
    // - LenderDeployer for deployment

    // -- Investors --
    mapping (address => uint) public investors;
    function relyInvestor(address usr) public auth note { investors[usr] = 1; }
    function denyInvestor(address usr) public auth note { investors[usr] = 0; }
    modifier auth_investor { require(investors[msg.sender] == 1); _; }

    constructor(address tranche_, address assessor_, address distributor_) BaseOperator(tranche_, assessor_, distributor_) public {}

    function supply(uint currencyAmount) external auth_investor {
        _supply(currencyAmount);
    }

    function redeem(uint tokenAmount) external auth_investor {
        _redeem(tokenAmount);
    }
}
