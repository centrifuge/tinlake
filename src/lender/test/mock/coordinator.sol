// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "../../../test/mock/mock.sol";

contract CoordinatorMock is Mock {
    function submissionPeriod() public view returns(bool) {
        return values_bool_return["submissionPeriod"];
    }

    function validate(uint juniorSupplyDAI, uint juniorRedeemDAI, uint seniorSupplyDAI, uint seniorRedeemDAI) public returns(int) {
        values_uint["seniorRedeem"] = seniorRedeemDAI;
        values_uint["juniorRedeem"] = juniorRedeemDAI;
        values_uint["seniorSupply"] = seniorSupplyDAI;
        values_uint["juniorSupply"] = juniorSupplyDAI;
        calls["validate"]++;
        return values_int_return["validate"];
    }
    function validatePoolConstraints(uint reserve_, uint seniorAsset_, uint nav_) external returns(int) {
        values_uint["reserve"] = reserve_;
        values_uint["seniorAsset"] = seniorAsset_;
        values_uint["nav"] = nav_;
        return values_int_return["validatePoolConstraints"];
    }

    function validateRatioConstraints(uint, uint) external view returns(int) {
//        values_uint["assets"] = assets_;
//        values_uint["seniorAsset"] = seniorAsset_;
        return values_int_return["validateRatioConstraints"];
    }

    function calcSeniorAssetValue(uint, uint, uint, uint, uint) public returns(uint) {
        return values_return["calcSeniorAssetValue"];
    }

    function calcSeniorRatio(uint, uint, uint) public returns(uint) {
        return values_return["calcSeniorRatio"];
    }
}
