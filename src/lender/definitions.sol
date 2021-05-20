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

pragma solidity >=0.6.12;

import "tinlake-math/math.sol";
import "./../fixed_point.sol";

// contract without a state which defines the relevant formulars for the assessor
contract Definitions is FixedPoint, Math {
    function calcExpectedSeniorAsset(uint _seniorDebt, uint _seniorBalance) public pure returns(uint) {
        return safeAdd(_seniorDebt, _seniorBalance);
    }

    /// calculates the senior ratio
    function calcSeniorRatio(uint seniorAsset, uint nav, uint reserve_) public pure returns(uint) {
        // note: NAV + reserve == seniorAsset + juniorAsset (loop invariant: always true)
        // if expectedSeniorAsset is passed ratio can be greater than ONE
        uint assets = calcAssets(nav, reserve_);
        if(assets == 0) {
            return 0;
        }

        return rdiv(seniorAsset, assets);
    }

    function calcSeniorRatio(uint seniorRedeem, uint seniorSupply,
            uint currSeniorAsset, uint newReserve, uint nav) public pure returns (uint seniorRatio)  {
        return calcSeniorRatio(calcSeniorAssetValue(seniorRedeem, seniorSupply,
            currSeniorAsset, newReserve, nav), nav, newReserve);
    }

/// calculates the net wealth in the system
    /// NAV for ongoing loans and currency in reserve
    function calcAssets(uint NAV, uint reserve_) public pure returns(uint) {
        return safeAdd(NAV, reserve_);
    }

    /// calculates a new senior asset value based on senior redeem and senior supply
    function calcSeniorAssetValue(uint seniorRedeem, uint seniorSupply,
        uint currSeniorAsset, uint reserve_, uint nav_) public pure returns (uint seniorAsset) {

        seniorAsset =  safeSub(safeAdd(currSeniorAsset, seniorSupply), seniorRedeem);
        uint assets = calcAssets(nav_, reserve_);
        if(seniorAsset > assets) {
            seniorAsset = assets;
        }

        return seniorAsset;
    }

    // expected senior return if no losses occur
    function calcExpectedSeniorAsset(uint seniorRedeem, uint seniorSupply, uint seniorBalance_, uint seniorDebt_) public returns(uint) {
        return safeSub(safeAdd(safeAdd(seniorDebt_, seniorBalance_),seniorSupply), seniorRedeem);
    }
}
