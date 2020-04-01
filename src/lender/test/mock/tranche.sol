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
import "../../../test/mock/mock.sol";

contract BaseTrancheMock is Mock {
    function debt() public view returns (uint) {
        return values_return["debt"];
    }

    function updatedDebt() public returns (uint) {
        calls["debt"]++;
        return values_return["debt"];
    }

    function drip() public {
        calls["drip"]++;
    }
    function supply(address usr, uint currencyAmount, uint tokenAmount) public {
        calls["supply"]++;
        values_address["usr"] = usr;
        values_uint["supply_currencyAmount"] = currencyAmount;
        values_uint["supply_tokenAmount"] = tokenAmount;
    }
    function redeem(address usr, uint currencyAmount, uint tokenAmount) public {
        calls["redeem"]++;
        values_address["redeem_usr"] = usr;
        values_uint["redeem_currencyAmount"] = currencyAmount;
        values_uint["redeem_tokenAmount"] = tokenAmount;
    }
    function tokenSupply() public view returns (uint) {
        return values_return["tokenSupply"];
    }

    function borrow(address usr, uint amount) public {
        calls["borrow"]++;
        values_address["borrow_usr"] = usr;
        values_uint["borrow_amount"] = amount;
    }

    function repay(address usr, uint amount) public {
        calls["repay"]++;
        values_address["repay_usr"] = usr;
        values_uint["repay_amount"] = amount;
    }
}

contract TrancheMock is BaseTrancheMock {
    function balance() public view returns (uint) {
        return values_return["balance"];
    }
}
