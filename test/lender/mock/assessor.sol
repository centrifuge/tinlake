// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";

contract AssessorMock is Mock {
    mapping(address => uint256) public tokenPrice;

    // legacy code Tinlake v0.2
    function calcAndUpdateTokenPrice(address tranche) public returns (uint256) {
        values_address["calcAndUpdateTokenPrice_tranche"] = tranche;
        return call("tokenPrice");
    }

    function calcAssetValue(address tranche) public returns (uint256) {
        values_address["calcAssetValue_tranche"] = tranche;
        return call("assetValue");
    }

    function juniorReserve() internal returns (uint256) {
        return call("juniorReserve");
    }

    function supplyApprove(address tranche, uint256 currencyAmount) public returns (bool) {
        calls["supplyApprove"]++;
        values_address["supplyApprove_tranche"] = tranche;
        values_uint["supplyApprove_currencyAmount"] = currencyAmount;

        return values_bool_return["supplyApprove"];
    }

    function redeemApprove(address tranche, uint256 currencyAmount) public returns (bool) {
        calls["redeemApprove"]++;
        values_address["redeemApprove_tranche"] = tranche;
        values_uint["redeemApprove_currencyAmount"] = currencyAmount;

        return values_bool_return["redeemApprove"];
    }

    function accrueTrancheInterest(address) public view returns (uint256) {
        return values_return["accrueTrancheInterest"];
    }

    function calcMaxSeniorAssetValue() external returns (uint256) {
        return call("calcMaxSeniorAssetValue");
    }

    function calcMinJuniorAssetValue() external returns (uint256) {
        return call("calcMinJuniorAssetValue");
    }

    function setTokenPrice(address tranche, uint256 tokenPrice_) public {
        tokenPrice[tranche] = tokenPrice_;
    }

    function calcTokenPrice(address tranche) external view returns (uint256) {
        return tokenPrice[tranche];
    }
    // - new funcs

    function calcUpdateNAV() external returns (uint256) {
        return call("calcUpdateNAV");
    }

    function maxReserve() external view returns (uint256) {
        return values_return["maxReserve"];
    }

    function calcSeniorTokenPrice(uint256, uint256) external returns (uint256) {
        return call("calcSeniorTokenPrice");
    }

    function calcJuniorTokenPrice(uint256, uint256) external returns (uint256) {
        return call("calcJuniorTokenPrice");
    }

    function calcSeniorTokenPrice() external view returns (uint256) {
        return values_return["calcSeniorTokenPrice"];
    }

    function calcJuniorTokenPrice() external view returns (uint256) {
        return values_return["calcJuniorTokenPrice"];
    }

    function calcSeniorAssetValue(uint256, uint256) external view returns (uint256) {
        return values_return["calcSeniorAssetValue"];
    }

    function seniorRatioBounds() public view returns (uint256 minSeniorRatio_, uint256 maxSeniorRatio_) {
        uint256 minSeniorRatio = values_return["minSeniorRatio"];
        uint256 maxSeniorRatio = values_return["maxSeniorRatio"];
        return (minSeniorRatio, maxSeniorRatio);
    }

    function seniorDebt() external view returns (uint256) {
        return values_return["seniorDebt"];
    }

    function seniorBalance() external view returns (uint256) {
        return values_return["seniorBalance"];
    }

    function effectiveSeniorBalance() external view returns (uint256) {
        return values_return["seniorBalance"];
    }

    function effectiveTotalBalance() external view returns (uint256) {
        return values_return["totalBalance"];
    }

    function calcExpectedSeniorAsset() external view returns (uint256) {
        return values_return["calcSeniorAssetValue"];
    }

    function changeSeniorAsset(uint256 seniorRatio_, uint256 seniorSupply, uint256 seniorRedeem) public {
        values_uint["changeSeniorAsset_seniorRatio"] = seniorRatio_;
        changeSeniorAsset(seniorSupply, seniorRedeem);
    }

    function changeSeniorAsset(uint256 seniorSupply, uint256 seniorRedeem) public {
        values_uint["changeSeniorAsset_seniorSupply"] = seniorSupply;
        values_uint["changeSeniorAsset_seniorRedeem"] = seniorRedeem;
    }

    function totalBalance() public view returns (uint256) {
        return values_return["balance"];
    }

    function changeBorrowAmountEpoch(uint256 currencyAmount) public {
        values_uint["changeBorrowAmountEpoch"] = currencyAmount;
    }

    function borrowAmountEpoch() public view returns (uint256) {
        return values_return["borrowAmountEpoch"];
    }

    function getNAV() public view returns (uint256) {
        return values_uint["getNAV"];
    }
}
