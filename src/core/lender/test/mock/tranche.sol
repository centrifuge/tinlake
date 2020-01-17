// Copyright (C) 2019 Centrifuge
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
import "./mock.sol";

contract TrancheMock is Mock {

    function setReturn(bytes32 name, uint returnValue) public {
        values_return[name] = returnValue;
    }

    function debt() public returns (uint) {
        return call("debt");
    }
    function balance() public returns (uint) {
        return call("balance");
    }
    function supply(address usr, uint currencyAmount, uint tokenAmount) public {
        calls["supply"]++;
        setReturn("currencyAmount", currencyAmount);
        setReturn("tokenAmount", tokenAmount);
    }
    function redeem(address usr, uint currencyAmount, uint tokenAmount) public {
        calls["redeem"]++;
        setReturn("currencyAmount", currencyAmount);
        setReturn("tokenAmount", tokenAmount);
    }
    function tokenSupply() public returns (uint) {
        return call("tokenSupply");
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