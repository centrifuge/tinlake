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
pragma solidity >=0.5.15 <0.6.0;

import "../interfaces.sol";

interface InvestorOperator {
    function supplyOrder(uint currencyAmount) external;
    function redeemOrder(uint redeemAmount) external;
    function disburse() external;
}

contract Investor {
    ERC20Like currency;
    ERC20Like token;

    InvestorOperator operator;

    constructor(address operator_, address currency_, address token_) public {
        currency = ERC20Like(currency_);
        token = ERC20Like(token_);
        operator = InvestorOperator(operator_);
    }

    function supplyOrder(uint currencyAmount) public {
        // todo
    }

}
