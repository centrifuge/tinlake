// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "src/lender/definitions.sol";

contract DefinitionsImpl is Definitions {}

contract DefinitionTest is Math, Test {
    Definitions def;

    function setUp() public {
        def = new DefinitionsImpl();
    }

    function testCalcSeniorRatio() public {
        uint256 seniorDebt = 300 ether;
        uint256 seniorBalance = 200 ether;
        uint256 NAV = 1000 ether;
        uint256 reserve = 1000 ether;

        assertEq(def.calcAssets(NAV, reserve), 2000 ether);
        // ratio 25%
        assertEq(def.calcSeniorRatio(safeAdd(seniorDebt, seniorBalance), NAV, reserve), 0.25 * 10 ** 27);
        assertEq(def.calcSeniorRatio(0, 0, 0), 0);
    }

    function testCalcSeniorAssetValue() public {
        uint256 newReserve = 800 ether;
        uint256 nav = 200 ether;

        uint256 currentSeniorAsset = 700 ether;
        uint256 seniorSupply = 120 ether;
        uint256 seniorRedeem = 20 ether;

        assertEq(800 ether, def.calcSeniorAssetValue(seniorRedeem, seniorSupply, currentSeniorAsset, newReserve, nav));
    }

    function testCalcSeniorAssetValueMoreThanAssets() public {
        uint256 newReserve = 800 ether;
        uint256 nav = 200 ether;

        uint256 currentSeniorAsset = 700 ether;
        uint256 seniorSupply = 500 ether;
        uint256 seniorRedeem = 0;

        assertEq(
            safeAdd(newReserve, nav),
            def.calcSeniorAssetValue(seniorRedeem, seniorSupply, currentSeniorAsset, newReserve, nav)
        );
    }

    function testCalcSeniorRatioDef() public {
        uint256 reserve = 800 ether;
        uint256 nav = 200 ether;
        uint256 seniorAssetValue = 600 ether;

        assertEq(def.calcSeniorRatio(seniorAssetValue, nav, reserve), 0.6 * 10 ** 27);
    }

    function testCalcSeniorRatioOverONE() public {
        uint256 reserve = 800 ether;
        uint256 nav = 200 ether;
        uint256 seniorAssetValue = 1500 ether;

        assertEq(def.calcSeniorRatio(seniorAssetValue, nav, reserve), 1.5 * 10 ** 27);
    }

    function testCalcSeniorRatioWithOrders() public {
        uint256 reserve = 800 ether;
        uint256 nav = 200 ether;
        uint256 seniorAssetValue = 700 ether;
        uint256 seniorSupply = 120 ether;
        uint256 seniorRedeem = 20 ether;

        assertEq(def.calcSeniorRatio(seniorRedeem, seniorSupply, seniorAssetValue, nav, reserve), 0.8 * 10 ** 27);
    }
}
