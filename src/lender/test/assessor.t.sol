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

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "./../assessor.sol";
import "./mock/tranche.sol";
import "./mock/navFeed.sol";

contract Hevm {
    function warp(uint256) public;
}

contract AssessorTest is DSTest, Math {
    Hevm hevm;
    Assessor assessor;
    TrancheMock seniorTranche;
    TrancheMock juniorTranche;
    NAVFeedMock navFeed;

    address seniorTranche_;
    address juniorTranche_;
    address navFeed_;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        seniorTranche = new TrancheMock();
        juniorTranche = new TrancheMock();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);

        navFeed = new NAVFeedMock();
        navFeed_ = address(navFeed);
        assessor = new Assessor();

        assessor.depend("juniorTranche", juniorTranche_);
        assessor.depend("seniorTranche", seniorTranche_);
        assessor.depend("navFeed", navFeed_);
    }

    function testCurrentNAV() public {
        navFeed.setReturn("calcUpdateNAV", 100 ether);
        assertEq(assessor.calcUpdateNAV(), 100 ether);
    }

    function testFileAssessor() public {
        uint maxReserve = 10000 ether;
        uint maxSeniorRatio = 80 * 10 **25;
        uint minSeniorRatio = 75 * 10 **25;
        uint seniorInterestRate = 1000000593415115246806684338; // 5% per day

        assessor.file("seniorInterestRate", seniorInterestRate);
        assertEq(assessor.seniorInterestRate(), seniorInterestRate);

        assessor.file("maxReserve", maxReserve);
        assertEq(assessor.maxReserve(), maxReserve);

        assessor.file("maxSeniorRatio", maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);

        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testFailFileMinRatio() public {
        // min needs to be smaller than max
        uint minSeniorRatio = 75 * 10 **25;
        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testFailFileMaxRatio() public {
        // min needs to be smaller than max
        uint minSeniorRatio = 75 * 10 **25;
        uint maxSeniorRatio = 80 * 10 **25;

        assessor.file("maxSeniorRatio", maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);

        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);

        // should fail
        assessor.file("maxSeniorRatio", minSeniorRatio-1);
    }

    function testBorrowUpdate() public {
        uint currencyAmount = 100 ether;
        assessor.borrowUpdate(currencyAmount);
        // current senior ratio 0 no change
        assertEq(assessor.seniorBalance(), 0);
        assertEq(assessor.seniorDebt(), 0);

        uint seniorSupply = 200 ether;
        uint seniorRatio = 6 * 10**26;
        assessor.changeSeniorAsset(seniorRatio, seniorSupply, 0);
        assertEq(assessor.seniorRatio(), seniorRatio);

        assessor.borrowUpdate(currencyAmount);
        // current senior ratio 0 no change

        uint increase = rmul(currencyAmount, seniorRatio);
        assertEq(assessor.seniorDebt(), increase);
        assertEq(assessor.seniorBalance(), seniorSupply-increase);


        // very high increase very rare case
        currencyAmount = 1000 ether;
        assessor.borrowUpdate(currencyAmount);

        assertEq(assessor.seniorDebt(), seniorSupply);
        assertEq(assessor.seniorBalance(), 0);
    }

    function testChangeSeniorAsset() public {
        uint seniorSupply =  100 ether;
        uint seniorRedeem = 0;
        uint seniorRatio = 6 * 10**26;
        assessor.changeSeniorAsset(seniorRatio, seniorSupply, seniorRedeem);

        // NAV = 0
        assertEq(assessor.seniorDebt(), 0);
        assertEq(assessor.seniorBalance(), seniorSupply);

        navFeed.setReturn("approximatedNAV", 10 ether);
        // update with no change
        assessor.changeSeniorAsset(seniorRatio, 0, 0);

        assertEq(assessor.seniorDebt(), 6 ether);
        assertEq(assessor.seniorBalance(), 94 ether);

        seniorSupply = 10 ether;
        seniorRedeem = 4 ether;
        // net increase of 6 ether
        assessor.changeSeniorAsset(seniorRatio, seniorSupply, seniorRedeem);

        assertEq(assessor.seniorDebt(), 6 ether);
        assertEq(assessor.seniorBalance(), 100 ether);
    }

    function testRepayUpdate() public {
        uint repayAmount = 100 ether;
        assessor.repaymentUpdate(repayAmount);
        // current senior ratio 0 no change
        assertEq(assessor.seniorBalance(), 0);
        assertEq(assessor.seniorDebt(), 0);

        uint seniorSupply = 200 ether;
        uint seniorRatio = 6 * 10**26;

        assessor.changeSeniorAsset(seniorRatio, seniorSupply, 0);
        assertEq(assessor.seniorRatio(), seniorRatio);
        // NAV = 0
        assertEq(assessor.seniorBalance(), 200 ether);

        // required to borrow first
        uint borrowAmount = 100 ether;
        assessor.borrowUpdate(borrowAmount);
        // 100 * 0.6 = 60 ether
        assertEq(assessor.seniorDebt(), 60 ether);
        assertEq(assessor.seniorBalance(), 140 ether);

        // 60 ether
        assertEq(assessor.seniorDebt(), rmul(borrowAmount, seniorRatio));
        repayAmount = 50 ether;

        assessor.repaymentUpdate(repayAmount);
        // 50 * 0.6 = 30 ether
        assertEq(assessor.seniorDebt(), 30 ether);
        assertEq(assessor.seniorBalance(), 170 ether);
    }

    function testSeniorInterest() public {
        // 5% per day
        uint interestRate = uint(1000000564701133626865910626);
        assessor.file("seniorInterestRate", interestRate);


        uint supplyAmount = 200 ether;
        navFeed.setReturn("approximatedNAV", 200 ether);

        uint seniorSupply = 200 ether;
        uint seniorRatio = 5 * 10**26;

        assessor.changeSeniorAsset(seniorRatio, seniorSupply, 0);
        assertEq(assessor.seniorDebt(), 100 ether);
        assertEq(assessor.seniorBalance(), 100 ether);

        hevm.warp(now + 1 days);
        assertEq(assessor.seniorDebt(), 105 ether);
        assessor.dripSeniorDebt();
        assertEq(assessor.seniorDebt(), 105 ether);

        hevm.warp(now +  1 days);
        assessor.dripSeniorDebt();
        assertEq(assessor.seniorDebt(), 110.25 ether);
    }

    function testCalcSeniorTokenPrice() public {
        assertEq(assessor.calcSeniorTokenPrice(0,0), ONE);

        uint reserve = 50 ether;
        uint nav = 50 ether;

        seniorTranche.setReturn("tokenSupply", 0);
        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve);
        assertEq(seniorTokenPrice, ONE);


        uint supplyAmount = 200 ether;
        navFeed.setReturn("approximatedNAV", 200 ether);

        uint seniorSupply = 200 ether;
        uint seniorRatio = 5 * 10**26;

        assessor.changeSeniorAsset(seniorRatio, seniorSupply, 0);
        assertEq(assessor.seniorDebt(), 100 ether);
        assertEq(assessor.seniorBalance(), 100 ether);


        seniorTranche.setReturn("tokenSupply", 100 ether);
        reserve = 100 ether;
        nav = 100 ether;
        seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve);
        // token price 2.0
        assertEq(seniorTokenPrice, 2 * 10 ** 27);


        reserve = 1000 ether;
        nav = 100 ether;
        seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve);
        assertEq(seniorTokenPrice, 2 * 10 ** 27);

        reserve = 100 ether;
        nav = 1000 ether;
        seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve);
        assertEq(seniorTokenPrice, 2 * 10 ** 27);

        reserve = 25 ether;
        nav = 25 ether;
        seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve);
        // price: 0.5
        assertEq(seniorTokenPrice, 5 * 10 ** 26);
    }

    function testCalcJuniorTokenPrice() public {
        assertEq(assessor.calcJuniorTokenPrice(0,0), ONE);

        uint reserve = 50 ether;
        uint nav = 50 ether;

        juniorTranche.setReturn("tokenSupply", 0);
        uint juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, reserve);
        assertEq(juniorTokenPrice, ONE);

        // set up senior asset
        uint supplyAmount = 200 ether;
        navFeed.setReturn("approximatedNAV", 200 ether);
        uint seniorSupply = 200 ether;
        uint seniorRatio = 5 * 10**26;

        assessor.changeSeniorAsset(seniorRatio, seniorSupply, 0);
        assertEq(assessor.seniorDebt(), 100 ether);
        assertEq(assessor.seniorBalance(), 100 ether);

        reserve = 300 ether;
        nav = 200 ether;

        juniorTranche.setReturn("tokenSupply", 100 ether);
        juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, reserve);
        // NAV + Reserve  = 500 ether
        // seniorAsset = 200 ether
        // juniorAsset = 300 ether

        // junior price: 3.0
        assertEq(juniorTokenPrice, 3 * 10 ** 27);

        reserve = 300 ether;
        nav = 0 ether;

        juniorTranche.setReturn("tokenSupply", 100 ether);
        juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, reserve);
        assertEq(juniorTokenPrice, ONE);

        reserve = 150 ether;
        nav = 0 ether;
        juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, reserve);
        assertEq(juniorTokenPrice, 0);

        seniorTranche.setReturn("tokenSupply", 200 ether);
        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, reserve);
        assertEq(seniorTokenPrice, 75 * 10**25);
    }
}
