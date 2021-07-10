// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

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

    function calcSeniorTokenPrice(uint, uint) external returns(uint) {
        return call("calcSeniorTokenPrice");
    }

    function calcJuniorTokenPrice(uint, uint) external returns(uint) {
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


    function totalBalance() public view returns (uint) {
        return values_return["balance"];
    }

    function changeBorrowAmountEpoch(uint currencyAmount) public {
        values_uint["changeBorrowAmountEpoch"] = currencyAmount;
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
