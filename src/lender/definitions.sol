// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";
import "./../fixed_point.sol";

// contract without a state which defines the relevant formulars for the assessor
contract Definitions is FixedPoint, Math {
    function calcExpectedSeniorAsset(uint256 _seniorDebt, uint256 _seniorBalance) public pure returns (uint256) {
        return safeAdd(_seniorDebt, _seniorBalance);
    }

    // calculates the senior ratio
    function calcSeniorRatio(uint256 seniorAsset, uint256 nav, uint256 reserve_) public pure returns (uint256) {
        // note: NAV + reserve == seniorAsset + juniorAsset (loop invariant: always true)
        // if expectedSeniorAsset is passed ratio can be greater than ONE
        uint256 assets = calcAssets(nav, reserve_);
        if (assets == 0) {
            return 0;
        }

        return rdiv(seniorAsset, assets);
    }

    function calcSeniorRatio(
        uint256 seniorRedeem,
        uint256 seniorSupply,
        uint256 currSeniorAsset,
        uint256 newReserve,
        uint256 nav
    ) public pure returns (uint256 seniorRatio) {
        return calcSeniorRatio(
            calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, newReserve, nav), nav, newReserve
        );
    }

    // calculates the net wealth in the system
    // NAV for ongoing loans and currency in reserve
    function calcAssets(uint256 NAV, uint256 reserve_) public pure returns (uint256) {
        return safeAdd(NAV, reserve_);
    }

    // calculates a new senior asset value based on senior redeem and senior supply
    function calcSeniorAssetValue(
        uint256 seniorRedeem,
        uint256 seniorSupply,
        uint256 currSeniorAsset,
        uint256 reserve_,
        uint256 nav_
    ) public pure returns (uint256 seniorAsset) {
        seniorAsset = safeSub(safeAdd(currSeniorAsset, seniorSupply), seniorRedeem);
        uint256 assets = calcAssets(nav_, reserve_);
        if (seniorAsset > assets) {
            seniorAsset = assets;
        }

        return seniorAsset;
    }

    // expected senior return if no losses occur
    function calcExpectedSeniorAsset(
        uint256 seniorRedeem,
        uint256 seniorSupply,
        uint256 seniorBalance_,
        uint256 seniorDebt_
    ) public pure returns (uint256) {
        return safeSub(safeAdd(safeAdd(seniorDebt_, seniorBalance_), seniorSupply), seniorRedeem);
    }
}
