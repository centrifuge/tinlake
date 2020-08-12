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

import "../../../test/mock/mock.sol";

contract AssessorMock is Mock {

    mapping(address => uint) public tokenPrice;

    function calcAndUpdateTokenPrice (address tranche) public returns (uint) {
        values_address["calcAndUpdateTokenPrice_tranche"]= tranche;
        return call("tokenPrice");
    }

    function calcAssetValue(address tranche) public returns (uint) {
        values_address["calcAssetValue_tranche"]= tranche;
        return call("assetValue");
    }

    function juniorReserve() internal returns (uint) {
        return call("juniorReserve");
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

    function accrueTrancheInterest(address) public view returns (uint) {
        return values_return["accrueTrancheInterest"];
    }

    function calcMaxSeniorAssetValue() external returns(uint) {
        return call("calcMaxSeniorAssetValue");
    }

    function calcMinJuniorAssetValue() external returns(uint) {
        return call("calcMinJuniorAssetValue");
    }

    function setTokenPrice(address tranche, uint tokenPrice_) public {
        tokenPrice[tranche] = tokenPrice_;
    }

    function calcTokenPrice(address tranche) external view returns(uint) {
        return tokenPrice[tranche];
    }
    // - new funcs

    function calcNAV() external returns (uint) {
        return call("calcNAV");
    }

    function maxReserve() external view returns (uint) {
        return values_return["maxReserve"];
    }

    function calcSeniorTokenPrice(uint NAV_) external returns(uint) {
        return call("calcSeniorTokenPrice");
    }

    function calcJuniorTokenPrice(uint NAV_) external returns(uint) {
        return call("calcJuniorTokenPrice");
    }

    function seniorRatioBounds() public view returns (uint minSeniorRatio, uint maxSeniorRatio) {
        uint minSeniorRatio = values_return["minSeniorRatio"];
        uint maxSeniorRatio = values_return["maxSeniorRatio"];
        return (minSeniorRatio, maxSeniorRatio);
    }

    function seniorDebt() external returns (uint) {
        return call("seniorDebt");
    }

    function seniorBalance() external returns (uint) {
        return call("seniorBalance");
    }
}
