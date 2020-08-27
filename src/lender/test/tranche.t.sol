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
import "./../ticker.sol";

contract Hevm {
    function warp(uint256) public;
}

contract TrancheTest is DSTest, Math {
    Tranche tranche;
    SimpleToken token;
    SimpleToken currency;
    ReserveMock reserve;
    Ticker ticker;

    Hevm hevm;

    address tranche_;
    address reserve_;
    address self;

    uint256 constant ONE = 10**27;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1595247588);

        ticker = new Ticker();
        reserve = new ReserveMock();
        reserve_ = address(reserve);
        token = new SimpleToken("TIN", "Tranche", "1", 0);
        currency = new SimpleToken("CUR", "Currency", "1", 0);
        tranche = new Tranche(address(currency), address(token));
        tranche.depend("ticker", address(ticker));
        tranche.depend("reserve", reserve_);

        tranche_ = address(tranche);

        self = address(this);
    }

    function testBalance() public {
        currency.mint(tranche_, 100 ether);
        currency.mint(self, 100 ether);
        uint256 b = tranche.balance();
        assertEq(b, 100 ether);
    }

    function testTokenSupply() public {
        token.mint(self, 100 ether);
        uint256 s = tranche.tokenSupply();
        assertEq(s, 100 ether);
    }

    function testSubmitRedeemOrder() public {
        uint investorBalance = 100 ether;
        uint redeemAmount = 80 ether;
        uint currentEpoch = 0;
        uint redeemEpochID = 10;

        // topup investor with tokens
        token.mint(self, investorBalance);
        assertEq(token.balanceOf(self), investorBalance);
        // rely investor on tranche
        tranche.rely(self);
        // investor approves tokens to be redeemed
        token.approve(tranche_, redeemAmount);
        // assert current epoch is currentEpoch => 1
        assertEq(ticker.currentEpoch(), currentEpoch);

        // submit redeem order for certain epoch -> epoch 10 amount 80 TKN
        tranche.redeemOrder(self, redeemEpochID, redeemAmount);

        // assert redeemAmount was transferred to the tranche & burned
        // new investor token balance: initialBlance - redeemAmount
        assertEq(token.balanceOf(self), safeSub(investorBalance, redeemAmount));
        // tranche balance = 0 -> tokens burned
        assertEq(token.balanceOf(tranche_), redeemAmount);
        (uint totalRedeem,,,,) = tranche.epochs(redeemEpochID);
        uint redeemTokenAmountTranche = tranche.redeemTokenAmount(redeemEpochID, self);
        // assert investor's redeem amount for redeemEpochID equals redeemAmount
        assertEq(redeemTokenAmountTranche, redeemAmount);
        // assert totalRedeem equals redeemAmount
        assertEq(totalRedeem, redeemAmount);
    }
    // fail case: epochID too low
    // fail case: not enough token balance
    // fail case: no allowance
    // fail case: tokens not approved

    function testSubmitSupplyOrder() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 80 ether;
        uint currentEpoch = 0;
        uint supplyEpochID = 10;
        uint trancheInitialBalance = currency.balanceOf(tranche_);

        // topup investor with currency
        currency.mint(self, investorBalance);
        assertEq(currency.balanceOf(self), investorBalance);
        // rely investor on tranche
        tranche.rely(self);
        // investor approves currency to be supplied
        currency.approve(tranche_, supplyAmount);
        // assert current epoch is currentEpoch => 1
        assertEq(ticker.currentEpoch(), currentEpoch);

        // submit supply order for certain epoch -> epoch 10 amount 80 DAI
        tranche.supplyOrder(self, supplyEpochID, supplyAmount);

        // assert supplyAmount was transferred to the tranche
        // new investor balance: initialBlance - supplyAmount
        assertEq(currency.balanceOf(self), safeSub(investorBalance, supplyAmount));
        // tranche balance = trancheInitialBalance + supplyAmount
        assertEq(currency.balanceOf(tranche_), safeAdd(trancheInitialBalance, supplyAmount));
        (, uint totalSupply,,,) = tranche.epochs(supplyEpochID);
        uint supplyCurrencyAmountTranche = tranche.supplyCurrencyAmount(supplyEpochID, self);
        // assert investor's supply amount for supplyEpochID equals supplyAmount
        assertEq(supplyCurrencyAmountTranche, supplyAmount);
        // assert totalSupply equals supplyAmount
        assertEq(totalSupply, supplyAmount);
    }
    // fail case: epoch too low, not enough balance
    // fail case: no allowance
    // fail case: currency not approved

    function testUpdateSupplyOrder() public {}
    function testUpdateRedeemOrder() public {}

    function testDisburse() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 100 ether;
        uint disburseEpochID = 10;
        uint tokenPrice = ONE;

        // supplyFullFillMent 80 %
        uint supplyFullfillment = rdiv(80, 100);
        uint redeemFullfillment = ONE;

        // topup investor with currency
        currency.mint(self, investorBalance);
        // rely investor on tranche
        tranche.rely(self);
        // investor approves currency to be supplied
        currency.approve(tranche_, supplyAmount);
        // submit supply order for certain epoch -> epoch 10 amount 80 DAI
        tranche.supplyOrder(self, disburseEpochID, supplyAmount);

        // settle epoch
        tranche.epochUpdate(disburseEpochID, supplyFullfillment, redeemFullfillment, tokenPrice);

        // assert tokens were minted for disbursement
        assertEq(token.balanceOf(tranche_), rmul(supplyAmount, supplyFullfillment));

        // disburse
        tranche.disburse(self, disburseEpochID);
        // check investor received correct amount of tokens
        assertEq(token.balanceOf(self), rdiv(rmul(supplyAmount, supplyFullfillment), tokenPrice));
        // check investor received correct amount of currency
        assertEq(currency.balanceOf(self), rmul(supplyAmount, safeSub(ONE, supplyFullfillment)));
        // check supplyCurrencyAmount of investor set to 0
        uint supplyCurrencyAmountTranche = tranche.supplyCurrencyAmount(disburseEpochID, self);
        assertEq(supplyCurrencyAmountTranche, 0);
        // check redeemTokenAmount of investor set to 0
        uint redeemTokenAmountTranche = tranche.redeemTokenAmount(disburseEpochID, self);
        assertEq(redeemTokenAmountTranche, 0);
        // check reserve received correct amount of currency
        assertEq(currency.balanceOf(reserve_), rmul(supplyAmount, supplyFullfillment));

        // assert tranche token balance is 0
        assertEq(token.balanceOf(tranche_), 0);
    }
    // test case: redeem disburse
    // test case: tokenPrice != 1
    // fail case: epoche not settled
}
