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

import "ds-test/test.sol";
import "tinlake-auth/auth.sol";
import "../../../test/mock/mock.sol";

interface CurrencyLike {
    function transferFrom(address from, address to, uint amount) external;
    function balanceOf(address usr) external returns (uint);
}

contract ReserveMock is Mock, Auth {
    CurrencyLike public currency;
    constructor(address currency_) public {
        wards[msg.sender] = 1;
        currency = CurrencyLike(currency_);
    }

    function file(bytes32 , uint currencyAmount) public auth {
        values_uint["currency_available"] = currencyAmount;
    }

    function balance() public returns (uint) {
        return call("balance");
    }

    function totalBalance() public returns (uint) {
        return call("balance");
    }

    function deposit(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(msg.sender, address(this), amount);
    }
    function payout(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }
}

