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

contract CoordinatorMock is Mock {
    function submissionPeriod() public returns(bool) {
        calls["submissionPeriod"]++;
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

    function calcSeniorAssetValue(uint, uint, uint, uint, uint) public returns(uint) {
        return values_return["calcSeniorAssetValue"];
    }

    function calcSeniorRatio(uint, uint, uint) public returns(uint) {
        return values_return["calcSeniorRatio"];
    }
}
