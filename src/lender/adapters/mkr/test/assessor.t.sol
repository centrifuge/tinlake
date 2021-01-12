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
import "./../../../test/mock/tranche.sol";
import "./../../../test/mock/navFeed.sol";
import "./../../../test/mock/reserve.sol";
import "./../../../test/mock/clerk.sol";
import "../../../../test/simple/token.sol";


contract Hevm {
    function warp(uint256) public;
}

contract AssessorMKRTest is DSTest, Interest {
    Hevm hevm;
    MKRAssessor assessor;
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

        assessor = new MKRAssessor();
        assessor.depend("juniorTranche", juniorTranche_);
        assessor.depend("seniorTranche", seniorTranche_);
        assessor.depend("navFeed", navFeed_);
        assessor.depend("reserve", reserveMock_);
        assessor.depend("clerk", clerk_);
    }

    function testSeniorBalance() public {
        uint remainingOvercollCredit = 90 ether;
        uint seniorSupply = 10 ether;
        assessor.changeSeniorAsset(seniorSupply, 0);
        clerk.setReturn("calcOvercollAmount", remainingOvercollCredit);
        // balance should not have an effect
        reserveMock.setReturn("balance", 1000 ether);
        assertEq(assessor.seniorBalance(), 100 ether);
    }

    function testTotalBalance() public {
        uint reserve = 10 ether;
        uint remainingCredit =  80 ether;
        reserveMock.setReturn("balance", reserve);
        clerk.setReturn("remainingCredit", remainingCredit);
        assertEq(assessor.totalBalance(), remainingCredit+reserve);
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

    function testTotalBalanceBuffer() public {
        uint nav = 20 ether;
        navFeed.setReturn("approximatedNAV", nav);
        uint reserve = 80 ether;
        reserveMock.setReturn("balance", reserve);
        assertEq(assessor.totalBalance(), 80 ether);
        // 5% per day)
        uint fee = 1000000593415115246806684338;
        clerk.setReturn("stabilityFeeRate", fee);

        uint creditLine = 100 ether;
        uint debt = 20 ether;
        clerk.setReturn("remainingCredit", creditLine-debt);
        clerk.setReturn("debt", debt);
        uint expectedTotalBalance = safeAdd(reserve, creditLine-debt);

        uint interest = safeSub(rmul(rpow(clerk.stabilityFeeRate(),
            safeSub(safeAdd(block.timestamp, assessor.creditBufferTime()), block.timestamp), ONE), debt), debt);

        expectedTotalBalance = expectedTotalBalance - interest;
        assertEq(assessor.totalBalance(), expectedTotalBalance);
    }

    function testSeniorBalanceBuffer() public {
        // add seniorBalance
        uint seniorSupply = 10 ether;
        assessor.changeSeniorAsset(seniorSupply, 0);

        uint effectiveSeniorBalance = assessor.effectiveSeniorBalance();

        // 5% per day)
        uint fee = 1000000593415115246806684338;
        clerk.setReturn("stabilityFeeRate", fee);

        uint creditLine = 100 ether;
        uint debt = 20 ether;
        uint remainingCredit = creditLine-debt;
        clerk.setReturn("remainingCredit", remainingCredit);
        clerk.setReturn("debt", debt);

        uint interest = safeSub(rmul(rpow(clerk.stabilityFeeRate(),
            safeSub(safeAdd(block.timestamp, assessor.creditBufferTime()), block.timestamp), ONE), debt), debt);

        uint overCollAmount = rmul(remainingCredit-interest, 1.1 * 10**27);
        clerk.setReturn("calcOvercollAmount", overCollAmount);

        uint expectedSeniorBalance = safeSub(overCollAmount, interest);
        assertEq(assessor.seniorBalance(), safeAdd(effectiveSeniorBalance, overCollAmount));
    }
}
