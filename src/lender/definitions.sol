// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";
import "./../fixed_point.sol";

/// @notice contract without a state which defines the relevant formulars for the assessor
abstract contract Definitions is FixedPoint, Math {
    /// @notice calculates the the expected Senior asset value
    /// @param _seniorDebt the current senior debt
    /// @param _seniorBalance the current senior balance
    /// @return _seniorAsset returns the senior asset value
    function calcExpectedSeniorAsset(uint256 _seniorDebt, uint256 _seniorBalance)
        public
        pure
        returns (uint256 _seniorAsset)
    {
        return safeAdd(_seniorDebt, _seniorBalance);
    }

    /// @notice calculates the senior ratio
    /// @param seniorAsset the current senior asset value
    /// @param nav the current NAV
    /// @param reserve the current reserve
    /// @return seniorRatio the senior ratio
    function calcSeniorRatio(uint256 seniorAsset, uint256 nav, uint256 reserve)
        public
        pure
        returns (uint256 seniorRatio)
    {
        // note: NAV + reserve == seniorAsset + juniorAsset (invariant: always true)
        // if expectedSeniorAsset is passed ratio can be greater than ONE
        uint256 assets = calcAssets(nav, reserve);
        if (assets == 0) {
            return 0;
        }

        return rdiv(seniorAsset, assets);
    }

    /// @notice calculates supply and redeem impact on the senior ratio
    /// @param seniorRedeem the senior redeem amount
    /// @param seniorSupply the senior supply amount
    /// @param currSeniorAsset the current senior asset value
    /// @param newReserve the new reserve (including the supply and redeem amounts)
    /// @param nav the current NAV
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

    /// @notice calculates the net wealth in the system
    /// @param nav_ the current NAV
    /// @param reserve_ the current reserve
    /// @return assets_ the total asset value (NAV + reserve)
    function calcAssets(uint256 nav_, uint256 reserve_) public pure returns (uint256 assets_) {
        return safeAdd(nav_, reserve_);
    }

    /// @notice calculates a new senior asset value based on senior redeem and senior supply
    /// @param seniorRedeem the senior redeem amount
    /// @param seniorSupply the senior supply amount
    /// @param currSeniorAsset the current senior asset value
    /// @param reserve_ the current reserve
    /// @param nav_ the current NAV
    /// @return seniorAsset the new senior asset value
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

    /// @notice expected senior return if no losses occur
    /// @param seniorRedeem the senior redeem amount
    /// @param seniorSupply the senior supply amount
    /// @param seniorBalance_ the current senior balance
    /// @param seniorDebt_ the current senior debt
    /// @return expectedSeniorAsset_ the expected senior asset value
    function calcExpectedSeniorAsset(
        uint256 seniorRedeem,
        uint256 seniorSupply,
        uint256 seniorBalance_,
        uint256 seniorDebt_
    ) public pure returns (uint256 expectedSeniorAsset_) {
        return safeSub(safeAdd(safeAdd(seniorDebt_, seniorBalance_), seniorSupply), seniorRedeem);
    }
}
