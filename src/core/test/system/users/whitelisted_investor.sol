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
pragma solidity >=0.5.12;

import "ds-test/test.sol";
import "../../../lender/deployer.sol";
import "../test_utils.sol";

contract WhitelistedInvestor is DSTest {
    WhitelistOperator operator;
    ERC20Like currency;
    ERC20Like token;

    constructor(address operator_, address currency_, address token_) public {
        operator = WhitelistOperator(operator_);
        currency = ERC20Like(currency_);
        token = ERC20Like(token_);
    }

    function doSupply(uint amount) public {
        address tranche_ = address(operator.tranche());
        currency.approve(tranche_, amount);
        operator.supply(amount);
    }

    function doRedeem(uint amount) public {
        address tranche_ = address(operator.tranche());
        token.approve(tranche_, amount);
        operator.redeem(amount);
    }
}