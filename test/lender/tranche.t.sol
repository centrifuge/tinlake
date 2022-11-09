// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/math.sol";

import "src/lender/tranche.sol";
import "../simple/token.sol";
import "./mock/reserve.sol";

interface Hevm {
    function warp(uint256) external;
}

contract User {
    function authTransfer(Tranche tranche, address erc20, address usr, uint256 amount) public {
        tranche.authTransfer(erc20, usr, amount);
    }
}

contract TrancheTest is Test, Math, FixedPoint {
    Tranche tranche;
    SimpleToken token;
    SimpleToken currency;
    ReserveMock reserve;

    Hevm hevm;

    address tranche_;
    address reserve_;
    address self;

    uint256 public currentEpoch;
    uint256 public lastEpochExecuted;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1595247588);
        self = address(this);

        token = new SimpleToken("TIN", "Tranche");
        currency = new SimpleToken("CUR", "Currency");
        reserve = new ReserveMock(address(currency));
        reserve_ = address(reserve);

        tranche = new Tranche(address(currency), address(token));
        tranche.depend("reserve", reserve_);

        currentEpoch = 1;
        lastEpochExecuted = 0;

        // epoch ticker is implemented in test suite
        tranche.depend("coordinator", address(this));

        tranche_ = address(tranche);

        // give reserve a lot of currency
        currency.mint(reserve_, 1000000000000 ether);
    }

    function closeAndUpdate(uint256 supplyFulfillment, uint256 redeemFulfillment, uint256 tokenPrice) public {
        (uint256 totalSupply, uint256 totalRedeem) = tranche.closeEpoch();
        uint256 epochID = currentEpoch++;
        tranche.epochUpdate(
            epochID, supplyFulfillment, redeemFulfillment, tokenPrice, totalSupply, rmul(totalRedeem, tokenPrice)
        );
        lastEpochExecuted++;
    }

    function supplyOrder(uint256 amount) public {
        currency.mint(self, amount);
        currency.approve(tranche_, amount);
        tranche.supplyOrder(self, amount);

        (, uint256 supply,) = tranche.users(self);
        assertEq(supply, amount);
    }

    function redeemOrder(uint256 tokenAmount) public {
        token.mint(self, tokenAmount);
        token.approve(tranche_, tokenAmount);
        tranche.redeemOrder(self, tokenAmount);
        (,, uint256 redeemAmount) = tranche.users(self);
        assertEq(tokenAmount, redeemAmount);
    }

    function testSupplyOrder() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);
        assertEq(tranche.totalSupply(), amount);

        // change order
        amount = 120 ether;
        supplyOrder(amount);
        assertEq(tranche.totalSupply(), amount);
    }

    function testSimpleCloseEpoch() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);
        assertEq(tranche.totalSupply(), amount);
        (uint256 totalSupply,) = tranche.closeEpoch();
        assertEq(totalSupply, amount);
    }

    function testFailSupplyAfterCloseEpoch() public {
        uint256 amount = 1000000000 ether;
        supplyOrder(amount);
        tranche.closeEpoch();
        currentEpoch++;
        supplyOrder(120 ether);
    }

    function testSimpleEpochUpdate() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint256 supplyFulfillment_ = 6 * 10 ** 26;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = ONE;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        assertEq(tranche.totalSupply(), 40 ether);
        assertTrue(tranche.waitingForUpdate() == false);
    }

    function testSimpleDisburse() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint256 supplyFulfillment_ = 6 * 10 ** 26;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = ONE;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // should receive 60% => 60 ether
        (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        ) = tranche.calcDisburse(self);

        assertEq(payoutTokenAmount, 60 ether);
        assertEq(remainingSupplyCurrency, 40 ether);

        // 50 %
        supplyFulfillment_ = 5 * 10 ** 26;
        redeemFulfillment_ = ONE;
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // should receive 80% => 80 ether
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            tranche.calcDisburse(self);

        // 100 * 0.6 + 40 * 0.5
        assertEq(payoutTokenAmount, 80 ether);
        assertEq(remainingSupplyCurrency, 20 ether);

        // execute disburse
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            tranche.disburse(self);
        assertEq(payoutTokenAmount, 80 ether);
        assertEq(remainingSupplyCurrency, 20 ether);

        assertEq(token.balanceOf(self), 80 ether);
    }

    function testRedeemDisburse() public {
        uint256 tokenAmount = 100 ether;
        redeemOrder(tokenAmount);

        reserve.setReturn("totalBalanceAvailable", type(uint256).max);

        uint256 supplyFulfillment_ = 0;

        // 50 % redeem fulfillment
        uint256 redeemFulfillment_ = 5 * 10 ** 26;
        // token price= 1.5
        uint256 tokenPrice_ = 15 * 10 ** 26;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // execute disburse
        (uint256 payoutCurrencyAmount,,,) = tranche.disburse(self);

        //        // 50 * 1.5 = 75 ether
        assertEq(payoutCurrencyAmount, 75 ether);
    }

    function testZeroEpochUpdate() public {
        // token price= 1.5
        uint256 tokenPrice_ = 15 * 10 ** 26;
        tranche.closeEpoch();
        currentEpoch++;
        tranche.epochUpdate(currentEpoch, 0, 0, tokenPrice_, 0, 0);
        lastEpochExecuted++;

        tranche.closeEpoch();
        currentEpoch++;
        tranche.epochUpdate(currentEpoch, 0, 0, 0, 0, 0);
    }

    function testMultipleRedeem() public {
        // increase to 100 ether
        uint256 tokenAmount = 100 ether;
        redeemOrder(tokenAmount);
        reserve.setReturn("totalBalanceAvailable", type(uint256).max);

        // 75 % for redeem Fulfillment
        closeAndUpdate(0, 7 * 10 ** 26, ONE);
        // 50 % for redeem Fulfillment
        closeAndUpdate(0, 5 * 10 ** 26, ONE);

        (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        ) = tranche.disburse(self);

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
        closeAndUpdate(0, 2 * 10 ** 26, ONE);

        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            tranche.disburse(self);
        assertEq(payoutCurrencyAmount, 3 ether);
    }

    function testChangeOrderAfterDisburse() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint256 supplyFulfillment_ = 6 * 10 ** 26;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = ONE;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // execute disburse
        tranche.disburse(self);

        // by changing the supply order to 0 currency is received back
        tranche.supplyOrder(self, 0);
        assertEq(currency.balanceOf(self), 40 ether);
        assertEq(token.balanceOf(self), 60 ether);
    }

    function testMint() public {
        uint256 amount = 120 ether;
        tranche.mint(self, amount);
        assertEq(token.balanceOf(self), amount);
    }

    function testDisburseEndEpoch() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);

        // 60 % fulfillment
        uint256 supplyFulfillment_ = 1 * 10 ** 26;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = ONE;

        // execute 3 times with 10% supply fulfillment
        for (uint256 i = 0; i < 3; i++) {
            closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        }

        // execute disburse
        (, uint256 payoutTokenAmount,,) = tranche.disburse(self, lastEpochExecuted);

        // total fulfillment
        // 100 * 0.1 = 10
        //  90 * 0.1 =  9
        // 81  * 0.1 =  8.1
        // total: 27.1

        assertEq(payoutTokenAmount, 27.1 ether);
    }

    function testDisburseEndEpochMultiple() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);

        // 10 % fulfillment
        uint256 supplyFulfillment_ = 1 * 10 ** 26;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = ONE;

        // execute 3 times with 10% supply fulfillment

        // first one has a cheaper price
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, 5 * 10 ** 26);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        (uint256 orderedInEpoch,,) = tranche.users(self);

        uint256 endEpoch = orderedInEpoch;

        // execute disburse first epoch
        (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        ) = tranche.disburse(self, endEpoch);

        // 10 currency for 20 tokens
        assertEq(payoutTokenAmount, 20 ether);
        assertEq(remainingSupplyCurrency, 90 ether);

        (uint256 updatedOrderedInEpoch,,) = tranche.users(self);
        // updated order should increase
        assertEq(orderedInEpoch + 1, updatedOrderedInEpoch);

        // try again with same endEpoch
        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            tranche.disburse(self, endEpoch);

        assertEq(payoutTokenAmount, 0);

        (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken) =
            tranche.disburse(self, endEpoch + 1);
        // 90 ether * 0.1
        assertEq(payoutTokenAmount, 9 ether);
    }

    function testEndEpochTooHigh() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);

        // 10 % fulfillment
        uint256 supplyFulfillment_ = 1 * 10 ** 26;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = ONE;

        // execute two times with 10 %
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // execute disburse with too high endEpoch
        uint256 endEpoch = 1000;

        (, uint256 payoutTokenAmount,,) = tranche.disburse(self, endEpoch);

        assertEq(payoutTokenAmount, 19 ether);
    }

    function testFailNotDisburseAllEpochsAndSupply() public {
        uint256 amount = 100 ether;
        supplyOrder(amount);

        // 10 % fulfillment
        uint256 supplyFulfillment_ = 1 * 10 ** 26;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = ONE;

        // execute two times with 10 %
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);
        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // disburse only one epoch

        (uint256 orderedInEpoch,,) = tranche.users(self);

        uint256 endEpoch = orderedInEpoch;

        // execute disburse first epoch
        tranche.disburse(self, endEpoch);

        // no try to change supply
        supplyOrder(0);
    }

    function testDisburseSupplyAndRedeem() public {
        uint256 supplyAmount = 100 ether;
        uint256 redeemAmount = 50 ether;
        supplyOrder(supplyAmount);
        redeemOrder(redeemAmount);

        // 60 % fulfillment
        uint256 supplyFulfillment_ = 6 * 10 ** 26;
        uint256 redeemFulfillment_ = 8 * 10 ** 26;
        uint256 tokenPrice_ = ONE;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // execute disburse
        (uint256 payoutCurrencyAmount, uint256 payoutTokenAmount,,) = tranche.disburse(self);

        assertEq(payoutTokenAmount, rmul(supplyAmount, supplyFulfillment_));
        assertEq(payoutCurrencyAmount, rmul(redeemAmount, redeemFulfillment_));
    }

    function testRecoveryTransfer() public {
        uint256 amount = 100 ether;
        address recoveryAddr = address(123);
        supplyOrder(amount);

        assertEq(currency.balanceOf(address(tranche)), amount);
        tranche.authTransfer(address(currency), recoveryAddr, amount);
        assertEq(currency.balanceOf(recoveryAddr), amount);
        assertEq(currency.balanceOf(address(tranche)), 0);
    }

    function testFailRecoveryTransferNotAdmin() public {
        uint256 amount = 100 ether;
        address recoveryAddr = address(123);
        supplyOrder(amount);

        assertEq(currency.balanceOf(address(tranche)), amount);

        User nonAdminUser = new User();
        nonAdminUser.authTransfer(tranche, address(currency), recoveryAddr, amount);
    }

    function testCalcDisburseRoundingOff() public {
        uint256 amount = 20 ether;
        supplyOrder(amount);

        uint256 supplyFulfillment_ = ONE;
        uint256 redeemFulfillment_ = ONE;
        uint256 tokenPrice_ = 3 * 10 ** 27;

        closeAndUpdate(supplyFulfillment_, redeemFulfillment_, tokenPrice_);

        // the disburse method should always round off
        (, uint256 payoutTokenAmount,,) = tranche.calcDisburse(self);

        // rdiv would round up in the 20/3 case but calc disburse should always round off
        // 20/3 = 6.666666666666666666 instead of (6.666666666666666667)
        assertEq(rdiv(amount, tokenPrice_) - payoutTokenAmount, 1);
    }
}
