// SPDX-License-Identifier: AGPL-3.0-only
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
    function calcExpectedSeniorAsset(uint seniorRedeem, uint seniorSupply, uint seniorBalance_, uint seniorDebt_) public pure returns(uint) {
        return safeSub(safeAdd(safeAdd(seniorDebt_, seniorBalance_),seniorSupply), seniorRedeem);
    }
}
