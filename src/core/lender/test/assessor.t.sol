// Copyright (C) 2019 Centrifuge

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

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import "tinlake-math/math.sol";
import "../assessor.sol";
import "./mock/pool.sol";
import "./mock/tranche.sol";

contract AssessorLike {
    function calcTokenPrice(address tranche) public returns (uint);
}
contract TestTranche is TrancheMock {
    function doCalcTokenPrice(address assessor_) public returns (uint) {
        return AssessorLike(assessor_).calcTokenPrice(address(this));
    }
}
contract AssessorTest is DSTest,Math {
    uint256 constant ONE = 10 ** 27;
    Assessor assessor;
    address assessor_;
    PoolMock pool;
    TestTranche senior = new TestTranche();
    TestTranche junior = new TestTranche();
    function setUp() public {
        pool = new PoolMock();
        assessor = new Assessor();
        assessor_ = address(assessor);
        assessor.depend("junior", address(junior));
        assessor.depend("senior", address(senior));
        assessor.depend("pool", address(pool));
        assessor.rely(address(junior));
        assessor.rely(address(senior));
    }
    function calcAssetValue(address tranche, uint seniorTrancheDebt, uint seniorTrancheReserve, uint juniorTrancheDebt, uint juniorTrancheReserve, uint poolValue) internal returns (uint) {
        pool.setReturn("totalValue", poolValue);
        senior.setReturn("balance",seniorTrancheReserve);
        senior.setReturn("debt", seniorTrancheDebt);
        junior.setReturn("balance", juniorTrancheReserve);
        junior.setReturn("debt", juniorTrancheDebt);
        return assessor.calcAssetValue(address(tranche));
    }
    function testSeniorAssetValueHealthyPool() public {
        uint seniorTrancheDebt = 200 ether;
        uint seniorTrancheReserve = 150 ether;
        // default 0 - junior tranche does not need to keep track of debt value
        uint juniorTrancheDebt = 0;
        uint juniorTrancheReserve = 50 ether;
        uint poolValue = 250 ether;
        uint assetValue = calcAssetValue(address(senior), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 350 ether);
    }
    function testSeniorAssetValueWithLosses() public {
        uint seniorTrancheDebt = 200 ether;
        uint seniorTrancheReserve = 150 ether;
        uint juniorTrancheDebt = 0;
        uint juniorTrancheReserve = 50 ether;
        uint poolValue = 100 ether;
        uint assetValue = calcAssetValue(address(senior), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 300 ether);
    }
    function testJuniorAssetValueHealthyPool() public {
        uint seniorTrancheDebt = 200 ether;
        uint seniorTrancheReserve = 150 ether;
        uint juniorTrancheDebt = 0;
        uint juniorTrancheReserve = 50 ether;
        uint poolValue = 800 ether;
        uint assetValue = calcAssetValue(address(junior), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 650 ether);
    }
    function testJuniorAssetValueWithLosses() public {
        uint seniorTrancheDebt = 500 ether;
        uint seniorTrancheReserve = 150 ether;
        uint juniorTrancheDebt = 0 ether;
        uint juniorTrancheReserve = 200 ether;
        uint poolValue = 200 ether;
        uint assetValue = calcAssetValue(address(junior), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 0);
    }
    function testCalcTokenPrice() public {
        uint poolValue = 100 ether;
        uint debt = poolValue;
        pool.setReturn("totalValue",poolValue);
        senior.setReturn("balance", 0);
        senior.setReturn("debt", debt);
        senior.setReturn("tokenSupply", debt);
        uint assetValue = 100 ether;
        assertEq(assetValue, assessor.calcAssetValue(address(senior)));
        uint tokenPrice = senior.doCalcTokenPrice(assessor_);
        assertEq(tokenPrice, ONE);
        // less token than assetValue
        uint tokenSupply = debt/2;
        senior.setReturn("tokenSupply",tokenSupply);
        tokenPrice = senior.doCalcTokenPrice(assessor_);
        assertEq(tokenPrice, ONE * 2);
        // more token than assetValue
        tokenSupply = debt*3;
        senior.setReturn("tokenSupply", tokenSupply);
        tokenPrice = senior.doCalcTokenPrice(assessor_);
        assertEq(tokenPrice, ONE/3);
        // edge case: tokenSupply zero
        senior.setReturn("tokenSupply",0);
        tokenPrice = senior.doCalcTokenPrice(assessor_);
        assertEq(tokenPrice, ONE);
        // decimal numbers
        tokenSupply = 2.7182818284590452 ether;
        debt = 3.14159265359 ether;
        senior.setReturn("debt", debt);
        pool.setReturn("totalValue", debt);
        assetValue = assessor.calcAssetValue(address(senior));
        // sanity check
        assertEq(assetValue, debt);
        senior.setReturn("tokenSupply",tokenSupply);
        tokenPrice = senior.doCalcTokenPrice(assessor_);
        assertEq(tokenPrice, rdiv(assetValue, tokenSupply));
    }

    function testFailBankrupt() public {
        uint poolValue = 0;
        pool.setReturn("totalValue", poolValue);
        senior.setReturn("tokenSupply", 10 ether);
        uint assetValue = assessor.calcAssetValue(address(senior));
        assertEq(assetValue, 0);
        senior.doCalcTokenPrice(assessor_);
    }

    function testTokenPriceWithInitialNAV() public {
        uint poolValue = 100 ether;
        uint debt = poolValue;

        uint initialNAV = 100;
        assessor.file("tokenAmountForONE", initialNAV);

        pool.setReturn("totalValue", poolValue);
        senior.setReturn("debt", debt);
        senior.setReturn("tokenSupply", debt);

        // assetValue 100 ether, supply 100 ether
        uint tokenPrice = senior.doCalcTokenPrice(assessor_);
        assertEq(tokenPrice, ONE*initialNAV);

        // less token than assetValue: assetValue 100 ether, supply 50 ether
        uint tokenSupply = debt/2;
        senior.setReturn("tokenSupply",tokenSupply);
        tokenPrice = senior.doCalcTokenPrice(assessor_);
        assertEq(tokenPrice, ONE * initialNAV*2);
    }


    function _setJuniorAssetValue(uint juniorAssetValue) internal {
        // junior asset value
        uint poolValue = juniorAssetValue;
        pool.setReturn("totalValue",poolValue);
        senior.setReturn("balance", 0);
        senior.setReturn("debt", 0);

        // check correct junior asset Value
        assertEq(assessor.calcAssetValue(assessor.junior()), poolValue);

    }

    function testCalcMaxSeniorAssetValue() public {
        // max junior ratio 20%
        uint minJuniorRatio = 2 * 10**26;
        assessor.file("minJuniorRatio" , minJuniorRatio);

        _setJuniorAssetValue(100 ether);


        // 20/80 split juniorAssetValue: 100 ether maxSeniorSupply should be 400 ether
        assertEq(assessor.calcMaxSeniorAssetValue(), 400 ether);

        // different max junior ratio 10%
        minJuniorRatio = 1 * 10**26;
        assessor.file("minJuniorRatio" , minJuniorRatio);

        // ratio 10/90 juniorAssetValue: 100 ether  maxSeniorSupply should be 900 ether
        assertEq(assessor.calcMaxSeniorAssetValue(), 900 ether);


        // change junior to 200 ether
        _setJuniorAssetValue(200 ether);

        // ratio 10/90 juniorAssetValue: 200 ether  maxSeniorSupply should be 1800 ether
        assertEq(assessor.calcMaxSeniorAssetValue(), 1800 ether);
    }

    function testCurrentJuniorRatio() public {
        uint poolValue = 200 ether;
        pool.setReturn("totalValue",poolValue);
        senior.setReturn("balance", 0);
        senior.setReturn("debt", 100 ether);

        // check junior and senior absolute
        assertEq(assessor.calcAssetValue(assessor.junior()), 100 ether);
        assertEq(assessor.calcAssetValue(assessor.senior()), 100 ether);

        // junior ratio should be 50%
        assertEq(assessor.currentJuniorRatio(), 5*ONE/10);

        // different ratio
        senior.setReturn("debt", 150 ether);
        // check junior and senior absolute
        assertEq(assessor.calcAssetValue(assessor.junior()), 50 ether);
        assertEq(assessor.calcAssetValue(assessor.senior()), 150 ether);

        // junior ratio should be 25%
        assertEq(assessor.currentJuniorRatio(), 25*ONE/100);

        // different ratio with a lot of decimals
        pool.setReturn("totalValue", 300 ether);
        senior.setReturn("debt", 200 ether);

        // check junior and senior absolute
        assertEq(assessor.calcAssetValue(assessor.junior()), 100 ether);
        assertEq(assessor.calcAssetValue(assessor.senior()), 200 ether);


        // junior ratio should be 33.33%
        assertEq(assessor.currentJuniorRatio(), 333333333333333333333333333);
    }

    function testSupplyApprove() public {
        // define minJuniorRatio with 20 %
        uint minJuniorRatio = 2*ONE/10;
        assessor.file("minJuniorRatio",minJuniorRatio);

        // set currentJuniorRatio to 25 %
        uint poolValue = 400 ether;
        pool.setReturn("totalValue",poolValue);
        senior.setReturn("balance", 0);
        senior.setReturn("debt", 300 ether);

        // check if correct
        assertEq(assessor.currentJuniorRatio(), 25 * 10**25);

        uint maxSupplyAmount = 100 ether;

        assertTrue(assessor.supplyApprove(assessor.senior(), maxSupplyAmount-1));
        // max possible supply amount 100 ether (would result in:
        assertTrue(assessor.supplyApprove(assessor.senior(), maxSupplyAmount));
        assertTrue(assessor.supplyApprove(assessor.senior(), maxSupplyAmount+1) == false);

        // random address should be false (if activated)
        assertTrue(assessor.supplyApprove(address(123), 1 ether) == false);

        // simulate additional ether supplied
        senior.setReturn("balance", 100 ether);
        assertEq(assessor.currentJuniorRatio(), minJuniorRatio);

        // junior always true
        assertTrue(assessor.supplyApprove(assessor.junior(), uint(-1)));

        // test not set
        assessor.file("minJuniorRatio",0);
        assertTrue(assessor.supplyApprove(assessor.senior(), uint(-1)));

        // junior always true
        assertTrue(assessor.supplyApprove(assessor.junior(), uint(-1)));

        // random address should be true (because not activated)
        assertTrue(assessor.supplyApprove(address(123), 1 ether) == true);
    }

    function testReedemApprove() public {
        // define minJuniorRatio with 20 %
        uint maxSeniorRatio = 2*ONE/10;
        assessor.file("minJuniorRatio",maxSeniorRatio);

        // set currentJuniorRatio to 25 %
        uint poolValue = 300 ether;
        pool.setReturn("totalValue",poolValue);
        senior.setReturn("balance", 0);
        junior.setReturn("balance", 100 ether);
        senior.setReturn("debt", 300 ether);

        // check if correct
        assertEq(assessor.currentJuniorRatio(), 25 * 10**25);

        // seniorAssetValue: 300 ether, juniorAssetValue 100 ether => 25 %

        // max possible juniorAssetValue
        // seniorAssetValue: 300 ether, juniorAssetValue: 75 ether => 20%
        // therefore maxReedem for senior: 25 ether

        assertTrue(assessor.redeemApprove(assessor.junior(), 25 ether));
        assertTrue(assessor.redeemApprove(assessor.junior(), 36 ether) == false);




    }

}