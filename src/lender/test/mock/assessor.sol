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

import "../../../test/mock/mock.sol";

contract AssessorMock is Mock {
    function calcTokenPrice (address tranche) public returns (uint) {
        values_address["calcTokenPrice_tranche"]= tranche;
        return call("tokenPrice");
    }

    function calcAssetValue(address tranche) public returns (uint) {
        values_address["calcAssetValue_tranche"]= tranche;
        return call("assetValue");
    }

    function juniorReserve() internal returns (uint) {
        return call("juniorReserve");
    }

    function seniorDebt() internal returns (uint) {
        return call("seniorDebt");
    }

    function supplyApprove(address tranche, uint currencyAmount) public returns(bool) {
        calls["supplyApprove"]++;
        values_address["supplyApprove_tranche"]= tranche;
        values_uint["supplyApprove_currencyAmount"]= currencyAmount;

        return values_bool_return["supplyApprove"];
    }

    function redeemApprove(address tranche, uint currencyAmount) public returns(bool) {
        calls["redeemApprove"]++;
        values_address["redeemApprove_tranche"]= tranche;
        values_uint["redeemApprove_currencyAmount"]= currencyAmount;

        return values_bool_return["redeemApprove"];
    }

    function accrueTrancheInterest(address tranche) public returns (uint) {
        calls["accrueTrancheInterest"]++;
        values_address["accrueTrancheInterest_tranche"] = tranche;

        return values_return["accrueTrancheInterest"];
    }
}