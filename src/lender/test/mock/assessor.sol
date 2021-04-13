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

    // legacy code Tinlake v0.2
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

    function calcUpdateNAV() external returns (uint) {
        return call("calcUpdateNAV");
    }

    function maxReserve() external view returns (uint) {
        return values_return["maxReserve"];
    }

    function calcSeniorTokenPrice(uint nav, uint reserve) external returns(uint) {
        return call("calcSeniorTokenPrice");
    }

    function calcJuniorTokenPrice(uint nav, uint reserve) external returns(uint) {
        return call("calcJuniorTokenPrice");
    }

    function calcSeniorTokenPrice() external view returns(uint) {
        return values_return["calcSeniorTokenPrice"];
    }

    function calcJuniorTokenPrice() external view returns(uint) {
        return values_return["calcJuniorTokenPrice"];
    }

     function calcSeniorAssetValue(uint, uint) external view returns(uint) {
          return values_return["calcSeniorAssetValue"];
     }

    function seniorRatioBounds() public view returns (uint minSeniorRatio_, uint maxSeniorRatio_) {
        uint minSeniorRatio = values_return["minSeniorRatio"];
        uint maxSeniorRatio = values_return["maxSeniorRatio"];
        return (minSeniorRatio, maxSeniorRatio);
    }

    function seniorDebt() external view returns (uint) {
        return values_return["seniorDebt"];
    }

    function seniorBalance() external view returns (uint) {
        return values_return["seniorBalance"];
    }

    function effectiveSeniorBalance() external view returns(uint) {
        return values_return["seniorBalance"];
    }
    function effectiveTotalBalance() external view returns(uint) {
        return values_return["totalBalance"];
    }

    function calcExpectedSeniorAsset() external view returns(uint) {
        return values_return["calcSeniorAssetValue"];
    }

    function changeSeniorAsset(uint seniorRatio_, uint seniorSupply, uint seniorRedeem) public {
        values_uint["changeSeniorAsset_seniorRatio"] = seniorRatio_;
        changeSeniorAsset(seniorSupply, seniorRedeem);

    }

    function changeSeniorAsset(uint seniorSupply, uint seniorRedeem) public {
        values_uint["changeSeniorAsset_seniorSupply"] = seniorSupply;
        values_uint["changeSeniorAsset_seniorRedeem"] = seniorRedeem;
    }


    function repaymentUpdate(uint currencyAmount) public  {
        values_uint["repaymentUpdate_currencyAmount"] = currencyAmount;

    }

    function borrowUpdate(uint currencyAmount) public  {
        values_uint["borrowUpdate_currencyAmount"] = currencyAmount;
    }

    function totalBalance() public view returns (uint) {
        return values_return["balance"];
    }

    function changeBorrowAmountEpoch(uint currencyAmount) public {
        values_uint["borrow_amount"] = currencyAmount;
    }

    function borrowAmountEpoch() public view returns(uint) {
        return values_return["borrowAmountEpoch"];
    }

    function currentNAV() public view returns(uint) {
        return values_uint["currentNAV"];
    }

    function getNAV() public view returns(uint) {
        return values_uint["getNAV"];
    }
}
