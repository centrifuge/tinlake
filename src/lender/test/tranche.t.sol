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

import "./../tranche.sol";
import "../../test/simple/token.sol";
import "../test/mock/reserve.sol";
import "../../../lib/tinlake-erc20/src/erc20.sol";

contract Hevm {
    function warp(uint256) public;
}

contract TrancheTest is DSTest, Math, FixedPoint {
    Tranche tranche;
    SimpleToken token;
    SimpleToken currency;
    ReserveMock reserve;

    Hevm hevm;

    address tranche_;
    address reserve_;
    address self;

    uint256 constant ONE = 10**27;

    uint public currentEpoch;
    uint public lastEpochExecuted;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1595247588);
        self = address(this);

        token = new SimpleToken("TIN", "Tranche", "1", 0);
        currency = new SimpleToken("CUR", "Currency", "1", 0);
        reserve = new ReserveMock(address(currency));
        reserve_ = address(reserve);

        tranche = new Tranche(address(currency), address(token));
        tranche.depend("reserve", reserve_);

        currentEpoch = 1;
        lastEpochExecuted = 0;

        // epoch ticker is implemented in test suite
        tranche.depend("epochTicker", address(this));

        tranche_ = address(tranche);

        // give reserve a lot of currency
        currency.mint(reserve_, 1000000000000 ether);
    }

    function closeAndUpdate(uint supplyFulfillment, uint redeemFulfillment, uint tokenPrice) public {
        (uint totalSupply, uint totalRedeem) = tranche.closeEpoch();
        uint epochID = currentEpoch++;
        tranche.epochUpdate(epochID, supplyFulfillment, redeemFulfillment, tokenPrice, totalSupply, rmul(totalRedeem, tokenPrice));
        lastEpochExecuted++;
    }

    function supplyOrder(uint amount) public {
        currency.mint(self, amount);
        currency.approve(tranche_, amount);
        tranche.supplyOrder(self, amount);

        (,uint supply,) = tranche.users(self);
        assertEq(supply, amount);
    }

    function redeemOrder(uint tokenAmount) public {
        token.mint(self, tokenAmount);
        token.approve(tranche_, tokenAmount);
        tranche.redeemOrder(self, tokenAmount);
        (,,uint redeemAmount) = tranche.users(self);
        assertEq(tokenAmount, redeemAmount);
    }

    function testSupplyOrder() public {
        uint amount = 100 ether;
        supplyOrder(amount);
        assertEq(tranche.totalSupply(), amount);

        // change order
        amount = 120 ether;
        supplyOrder(amount);
        assertEq(tranche.totalSupply(), amount);

    }

    function testSimpleCloseEpoch() public {
        uint amount = 100 ether;
        supplyOrder(amount);
        assertEq(tranche.totalSupply(), amount);
        (uint totalSupply, ) = tranche.closeEpoch();
        assertEq(totalSupply, amount);
    }

    function testFailSupplyAfterCloseEpoch() public {
        uint amount = 1000000000 ether;
        supplyOrder(amount);
        tranche.closeEpoch();
        currentEpoch++;
        supplyOrder(120 ether);
    }

    function testSimpleEpochUpdate() public {
        uint amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint supplyFulfillment_ = 6 * 10**26;
        uint redeemFulfillment_ = ONE;
        uint tokenPrice_ = ONE;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        assertEq(tranche.totalSupply(), 40 ether);
        assertTrue(tranche.waitingForUpdate() == false);
    }

    function testSimpleDisburse() public {
        uint amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint supplyFulfillment_ = 6 * 10**26;
        uint redeemFulfillment_ = ONE;
        uint tokenPrice_ = ONE;

        closeAndUpdate(supplyFulfillment_,redeemFulfillment_, tokenPrice_);

        // should receive 60% => 60 ether
        (uint payoutCurrencyAmount, uint payoutTokenAmount,
        uint remainingSupplyCurrency,  uint remainingRedeemToken) =  tranche.calcDisburse(self);

        assertEq(payoutTokenAmount, 60 ether);
        assertEq(remainingSupplyCurrency, 40 ether);

        // 50 %
        supplyFulfillment_ = 5 * 10**26;
        redeemFulfillment_ = ONE;
        closeAndUpdate(supplyFulfillment_,redeemFulfillment_, tokenPrice_);


        // should receive 80% => 80 ether
        (payoutCurrencyAmount, payoutTokenAmount,
         remainingSupplyCurrency, remainingRedeemToken) =  tranche.calcDisburse(self);

        // 100 * 0.6 + 40 * 0.5
        assertEq(payoutTokenAmount, 80 ether);
        assertEq(remainingSupplyCurrency, 20 ether);

        // execute disburse
        (payoutCurrencyAmount, payoutTokenAmount,
        remainingSupplyCurrency, remainingRedeemToken) =  tranche.disburse(self);
        assertEq(payoutTokenAmount, 80 ether);
        assertEq(remainingSupplyCurrency, 20 ether);

        assertEq(token.balanceOf(self), 80 ether);
    }

    function testRedeemDisburse() public {
        uint tokenAmount = 100 ether;
        redeemOrder(tokenAmount);

        reserve.setReturn("balance", uint(-1));

        uint supplyFulfillment_ = 0;

        // 50 % redeem fulfillment
        uint redeemFulfillment_ = 5 * 10**26;
        // token price= 1.5
        uint tokenPrice_ = 15 * 10 **26;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);


        // execute disburse
        (uint payoutCurrencyAmount,  ,
        , ) =  tranche.disburse(self);

//        // 50 * 1.5 = 75 ether
        assertEq(payoutCurrencyAmount, 75 ether);
    }

    function testZeroEpochUpdate() public {
        // token price= 1.5
        uint tokenPrice_ = 15 * 10 **26;
        tranche.closeEpoch();
        currentEpoch++;
        tranche.epochUpdate(currentEpoch, 0, 0, tokenPrice_, 0, 0);
        lastEpochExecuted++;

        tranche.closeEpoch();
        currentEpoch++;
        tranche.epochUpdate(currentEpoch,0, 0, 0, 0, 0);
    }

    function testMultipleRedeem() public {
        // increase to 100 ether
        uint tokenAmount = 100 ether;
        redeemOrder(tokenAmount);
        reserve.setReturn("balance", uint(-1));


        // 75 % for redeem Fulfillment
        closeAndUpdate(0,7 * 10**26, ONE);
        // 50 % for redeem Fulfillment
        closeAndUpdate(0,5 * 10**26, ONE);

        (uint payoutCurrencyAmount, uint payoutTokenAmount,
        uint remainingSupplyCurrency, uint remainingRedeemToken) =  tranche.disburse(self);

       // currency payout = 100 * 0.7 + 30 * 0.5 = 85 ether
        assertEq(payoutCurrencyAmount, 85 ether);
        assertEq(currency.balanceOf(self), 85 ether);

        // get token back
        assertEq(token.balanceOf(self), 0);
        assertEq(remainingRedeemToken, 15 ether);
        redeemOrder(0);
        assertEq(token.balanceOf(self), 15 ether);

        // redeem again
        redeemOrder(15 ether);
        // 20 % for redeem Fulfillment
        closeAndUpdate(0, 2 * 10**26, ONE);

        ( payoutCurrencyAmount, payoutTokenAmount,
         remainingSupplyCurrency, remainingRedeemToken) =  tranche.disburse(self);
        assertEq(payoutCurrencyAmount, 3 ether);

    }

    function testChangeOrderAfterDisburse() public {
        uint amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint supplyFulfillment_ = 6 * 10**26;
        uint redeemFulfillment_ = ONE;
        uint tokenPrice_ = ONE;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // execute disburse
        tranche.disburse(self);

        // by changing the supply order to 0 currency is received back
        tranche.supplyOrder(self, 0);
        assertEq(currency.balanceOf(self), 40 ether);
        assertEq(token.balanceOf(self), 60 ether);
    }

    function testMint() public {
        uint amount = 120 ether;
        tranche.mint(self, amount);
        assertEq(token.balanceOf(self), amount);
    }

    function testDisburseEndEpoch() public {
        uint amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint supplyFulfillment_ = 1 * 10**26;
        uint redeemFulfillment_ = ONE;
        uint tokenPrice_ = ONE;

        // execute 3 times with 10% supply fulfillment
        for (uint i = 0; i < 3; i++) {
            closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        }

        // execute disburse
        (, uint payoutTokenAmount, , ) =  tranche.disburse(self, lastEpochExecuted);

        // total fulfillment
        // 100 * 0.1 = 10
        //  90 * 0.1 =  9
        // 81  * 0.1 =  8.1
        // total: 27.1

        assertEq(payoutTokenAmount, 27.1 ether);
    }

    function testDisburseEndEpochMultiple() public {
        uint amount = 100 ether;
        supplyOrder(amount);

        // 10 % fulfillment
        uint supplyFulfillment_ = 1 * 10**26;
        uint redeemFulfillment_ = ONE;
        uint tokenPrice_ = ONE;

        // execute 3 times with 10% supply fulfillment

        // first one has a cheaper price
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, 5 * 10**26);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);


        (uint orderedInEpoch, ,) = tranche.users(self);

        uint endEpoch = orderedInEpoch;

        // execute disburse first epoch
        (uint payoutCurrencyAmount, uint payoutTokenAmount,
        uint remainingSupplyCurrency, uint remainingRedeemToken) =  tranche.disburse(self, endEpoch);


        // 10 currency for 20 tokens
        assertEq(payoutTokenAmount, 20 ether);
        assertEq(remainingSupplyCurrency, 90 ether);

        (uint updatedOrderedInEpoch, ,) = tranche.users(self);
        // updated order should increase
        assertEq(orderedInEpoch+1, updatedOrderedInEpoch);

        // try again with same endEpoch
        ( payoutCurrencyAmount,  payoutTokenAmount,
         remainingSupplyCurrency,  remainingRedeemToken) =  tranche.disburse(self, endEpoch);

        assertEq(payoutTokenAmount, 0);

        ( payoutCurrencyAmount,  payoutTokenAmount,
        remainingSupplyCurrency,  remainingRedeemToken) =  tranche.disburse(self, endEpoch+1);
        // 90 ether * 0.1
        assertEq(payoutTokenAmount, 9 ether);

    }

    function testEndEpochTooHigh() public {
        uint amount = 100 ether;
        supplyOrder(amount);

        // 10 % fulfillment
        uint supplyFulfillment_ = 1 * 10**26;
        uint redeemFulfillment_ = ONE;
        uint tokenPrice_ = ONE;

        // execute two times with 10 %
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // execute disburse with too high endEpoch
        uint endEpoch = 1000;

        (,uint payoutTokenAmount, , ) =  tranche.disburse(self, endEpoch);

        assertEq(payoutTokenAmount, 19 ether);
    }

    function testFailNotDisburseAllEpochsAndSupply() public {
        uint amount = 100 ether;
        supplyOrder(amount);

        // 10 % fulfillment
        uint supplyFulfillment_ = 1 * 10**26;
        uint redeemFulfillment_ = ONE;
        uint tokenPrice_ = ONE;

        // execute two times with 10 %
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // disburse only one epoch

        (uint orderedInEpoch, ,) = tranche.users(self);

        uint endEpoch = orderedInEpoch;

        // execute disburse first epoch
        tranche.disburse(self, endEpoch);

        // no try to change supply
        supplyOrder(0);
    }

    function testDisburseSupplyAndRedeem() public {
       // todo test supply and redeem simultaneously
    }
}
