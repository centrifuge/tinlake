// Copyright (C) 2019  Centrifuge
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
import "ds-math/math.sol";
import "../assessor.sol";
import "./mock/pool.sol";
import "./mock/tranche.sol";
contract AssessorLike {
    function calcTokenPrice() public returns (uint);
}
contract TestTranche is TrancheMock {
    function doCalcTokenPrice(address assessor_) public returns (uint) {
        return AssessorLike(assessor_).calcTokenPrice();
    }
}
contract AssessorTest is DSTest,DSMath {
    uint256 constant ONE = 10 ** 27;
    Assessor assessor;
    address assessor_;
    PoolMock pool;
    TestTranche senior = new TestTranche();
    TestTranche junior = new TestTranche();
    function setUp() public {
        pool = new PoolMock();
        assessor = new Assessor(address(pool));
        assessor_ = address(assessor);
        assessor.file("junior", address(junior));
        assessor.file("senior", address(senior));
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
        uint tokenPrice = senior.doCalcTokenPrice(assessor_);
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

}