// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";
import "src/lender/definitions.sol";

contract DefinitionTest is Math, DSTest {
    Definitions def;

    function setUp() public {
        def = new Definitions();
    }

    function testCalcSeniorRatio() public {
        uint seniorDebt = 300 ether;
        uint seniorBalance = 200 ether;
        uint NAV = 1000 ether;
        uint reserve = 1000 ether;

        assertEq(def.calcAssets(NAV, reserve), 2000 ether);
        // ratio 25%
        assertEq(def.calcSeniorRatio(safeAdd(seniorDebt,seniorBalance), NAV, reserve), 0.25 * 10**27);
        assertEq(def.calcSeniorRatio(0, 0, 0), 0);
    }

    function testCalcSeniorAssetValue() public {
        uint newReserve = 800 ether;
        uint nav = 200 ether;

        uint currentSeniorAsset = 700 ether;
        uint seniorSupply = 120 ether;
        uint seniorRedeem = 20 ether;

        assertEq(800 ether,
            def.calcSeniorAssetValue(seniorRedeem, seniorSupply, currentSeniorAsset, newReserve, nav));
    }

    function testCalcSeniorAssetValueMoreThanAssets() public {
        uint newReserve = 800 ether;
        uint nav = 200 ether;

        uint currentSeniorAsset = 700 ether;
        uint seniorSupply = 500 ether;
        uint seniorRedeem = 0;

        assertEq(safeAdd(newReserve, nav),
            def.calcSeniorAssetValue(seniorRedeem, seniorSupply, currentSeniorAsset, newReserve, nav));
    }

    function testCalcSeniorRatioDef() public {
        uint reserve = 800 ether;
        uint nav = 200 ether;
        uint seniorAssetValue = 600 ether;

        assertEq(def.calcSeniorRatio(seniorAssetValue, nav, reserve), 0.6 * 10**27);
    }

    function testCalcSeniorRatioOverONE() public {
        uint reserve = 800 ether;
        uint nav = 200 ether;
        uint seniorAssetValue = 1500 ether;

        assertEq(def.calcSeniorRatio(seniorAssetValue, nav, reserve), 1.5 * 10**27);
    }

    function testCalcSeniorRatioWithOrders() public {
        uint reserve = 800 ether;
        uint nav = 200 ether;
        uint seniorAssetValue = 700 ether;
        uint seniorSupply = 120 ether;
        uint seniorRedeem = 20 ether;

        assertEq(def.calcSeniorRatio(seniorRedeem, seniorSupply, seniorAssetValue, nav, reserve), 0.8 * 10**27);
    }
}
