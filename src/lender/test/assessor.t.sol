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
import "./mock/reserve.sol";
import "./mock/clerk.sol";
import "../../test/simple/token.sol";

contract Hevm {
    function warp(uint256) public;
}

contract AssessorTest is DSTest, Math {
    Hevm hevm;
    Assessor assessor;
    TrancheMock seniorTranche;
    TrancheMock juniorTranche;
    NAVFeedMock navFeed;
    ReserveMock reserveMock;
    SimpleToken currency;
    ClerkMock clerk;

    address seniorTranche_;
    address juniorTranche_;
    address navFeed_;
    address reserveMock_;
    address clerk_;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        currency = new SimpleToken("CUR", "Currency");

        seniorTranche = new TrancheMock();
        juniorTranche = new TrancheMock();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);

        navFeed = new NAVFeedMock();
        navFeed_ = address(navFeed);

        reserveMock = new ReserveMock(address(currency));
        reserveMock_ = address(reserveMock);

        clerk = new ClerkMock();
        clerk_ = address(clerk);

        assessor = new Assessor();
        assessor.depend("juniorTranche", juniorTranche_);
        assessor.depend("seniorTranche", seniorTranche_);
        assessor.depend("navFeed", navFeed_);
        assessor.depend("reserve", reserveMock_);
        assessor.depend("lending", clerk_);
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


        navFeed.setReturn("approximatedNAV", 0 ether);
        reserveMock.setReturn("balance", 1000 ether);


        uint seniorSupply = 800 ether;
        uint seniorRatio = 0.8 * 10**27;
        assessor.changeSeniorAsset(seniorSupply, 0);
        assertEq(assessor.seniorRatio(), seniorRatio);

        assessor.borrowUpdate(currencyAmount);
        // current senior ratio 0 no change

        uint increase = rmul(currencyAmount, seniorRatio);
        assertEq(assessor.seniorDebt(), increase);
        assertEq(assessor.seniorBalance(), seniorSupply-increase);


        // very high increase very rare case
        currencyAmount = 10000 ether;
        assessor.borrowUpdate(currencyAmount);

        assertEq(assessor.seniorDebt(), seniorSupply);
        assertEq(assessor.seniorBalance(), 0);
    }

    function testChangeSeniorAsset() public {
        uint seniorSupply =  80 ether;
        uint seniorRedeem = 0;

        navFeed.setReturn("approximatedNAV", 10 ether);
        reserveMock.setReturn("balance", 90 ether);


        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 8 ether);
        assertEq(assessor.seniorBalance(), seniorSupply - 8 ether);
    }

    function testChangeSeniorAssetOnlySenior() public {
        uint seniorSupply =  100 ether;
        uint seniorRedeem = 0;

        navFeed.setReturn("approximatedNAV", 10 ether);
        reserveMock.setReturn("balance", 90 ether);


        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 10 ether);
        assertEq(assessor.seniorBalance(), seniorSupply - 10 ether);
    }

    function testChangeSeniorAssetNoNAV() public {
        uint seniorSupply =  100 ether;
        uint seniorRedeem = 0;

        navFeed.setReturn("approximatedNAV", 0);
        reserveMock.setReturn("balance", 120 ether);


        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 0);
        assertEq(assessor.seniorBalance(), seniorSupply);
    }

    function testChangeSeniorAssetFullSenior() public {
        uint seniorSupply =  100 ether;
        uint seniorRedeem = 0;

        navFeed.setReturn("approximatedNAV", 10 ether);
        reserveMock.setReturn("balance", 50 ether);


        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 10 ether);
        assertEq(assessor.seniorBalance(), 90 ether);
    }

    function testRepayUpdate() public {
        uint repayAmount = 100 ether;
        assessor.repaymentUpdate(repayAmount);
        // current senior ratio 0 no change
        assertEq(assessor.seniorBalance(), 0);
        assertEq(assessor.seniorDebt(), 0);

        navFeed.setReturn("approximatedNAV", 0 ether);
        reserveMock.setReturn("balance", 1000 ether);

        uint seniorSupply = 800 ether;
        uint seniorRatio = 0.8 * 10**27;

        assessor.changeSeniorAsset(seniorSupply, 0);
        assertEq(assessor.seniorRatio(), seniorRatio);
        // NAV = 0
        assertEq(assessor.seniorBalance(), 800 ether);

        // required to borrow first
        uint borrowAmount = 100 ether;
        assessor.borrowUpdate(borrowAmount);
        // 100 * 0.6 = 60 ether
        assertEq(assessor.seniorDebt(), 80 ether);
        assertEq(assessor.seniorBalance(), 720 ether);

        // 80 ether
        assertEq(assessor.seniorDebt(), rmul(borrowAmount, seniorRatio));
        repayAmount = 50 ether;

        assessor.repaymentUpdate(repayAmount);
        // 50 * 0.8 = 30 ether
        assertEq(assessor.seniorDebt(), 40 ether);
        assertEq(assessor.seniorBalance(), 760 ether);
    }

    function testSeniorInterest() public {
        // 5% per day
        uint interestRate = uint(1000000564701133626865910626);
        assessor.file("seniorInterestRate", interestRate);

        navFeed.setReturn("approximatedNAV", 200 ether);
        reserveMock.setReturn("balance", 200 ether);

        uint seniorSupply = 200 ether;

        // seniorRatio 50%
        assessor.changeSeniorAsset(seniorSupply, 0);
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
        uint nav = 10 ether;
        navFeed.setReturn("approximatedNAV", nav);
        uint seniorSupply = 80 ether;
        reserveMock.setReturn("balance", 100 ether);

        assessor.changeSeniorAsset(seniorSupply, 0);
        seniorTranche.setReturn("tokenSupply", 40 ether);

        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 123123 ether);
        // seniorAsset: 80 ether, tokenSupply: 40 ether
        assertEq(seniorTokenPrice, 2 * 10**27);

        reserveMock.setReturn("balance", 30 ether);
        seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 123123 ether);
        // seniorAsset: 40 ether, tokenSupply: 40 ether
        assertEq(seniorTokenPrice, 1 * 10**27);
    }

    function testCalcJuniorTokenPrice() public {
        uint nav = 10 ether;
        navFeed.setReturn("approximatedNAV", nav);
        uint seniorSupply = 80 ether;
        reserveMock.setReturn("balance", 90 ether);

        assessor.changeSeniorAsset(seniorSupply, 0);
        juniorTranche.setReturn("tokenSupply", 20 ether);
        uint juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, 123123 ether);

        assertEq(juniorTokenPrice, 1 * 10**27);

        clerk.setReturn("juniorStake", 20 ether);
        juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, 123123 ether);

        assertEq(juniorTokenPrice, 2 * 10**27);
    }

    function testCalcTokenPrices() public {
        (uint juniorPrice, uint seniorPrice) = assessor.calcTokenPrices(0,0);
        assertEq(juniorPrice, ONE);
        assertEq(seniorPrice, ONE);

        uint reserve = 300 ether;
        uint nav = 200 ether;


        navFeed.setReturn("approximatedNAV", 200 ether);
        reserveMock.setReturn("balance", 200 ether);

        uint seniorSupply = 200 ether;

        // seniorRatio 50%
        assessor.changeSeniorAsset(seniorSupply, 0);
        assertEq(assessor.seniorDebt(), 100 ether);
        assertEq(assessor.seniorBalance(), 100 ether);

        reserve = 300 ether;
        nav = 200 ether;

        juniorTranche.setReturn("tokenSupply", 100 ether);
        // NAV + Reserve  = 500 ether
        // seniorAsset = 200 ether
        // juniorAsset = 300 ether

        // junior price: 3.0
        (juniorPrice, seniorPrice) = assessor.calcTokenPrices(nav, reserve);
        assertEq(juniorPrice, 3 * 10 ** 27);
        assertEq(seniorPrice, 1 * 10 ** 27);
    }

    function testTotalBalance() public {
        uint totalBalance = 100 ether;
        reserveMock.setReturn("balance", totalBalance);
        assertEq(assessor.totalBalance(), totalBalance);
    }

    function testchangeBorrowAmountEpoch() public {
        uint amount = 100 ether;
        assertEq(reserveMock.values_uint("borrow_amount"), 0);
        assessor.changeBorrowAmountEpoch(amount);
        assertEq(reserveMock.values_uint("borrow_amount"), amount);
    }
}
