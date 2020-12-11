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
import "../adapters/mkr/clerk.sol";
import "tinlake-math/math.sol";

import "../../test/simple/token.sol";
import "../test/mock/reserve.sol";
import "../test/mock/coordinator.sol";
import "../test/mock/navFeed.sol";
import "../test/mock/assessor.sol";
import "../test/mock/tranche.sol";
import "../test/mock/mkr/mgr.sol";
import "../test/mock/mkr/spotter.sol";
import "../test/mock/mkr/vat.sol";

contract Hevm {
    function warp(uint256) public;
}

contract ClerkTest is Math, DSTest {

    Hevm hevm;
    
    uint256 constant ONE = 10 ** 27;

    SimpleToken currency;
    SimpleToken collateral;
    ReserveMock reserve;
    AssessorMock assessor;
    CoordinatorMock coordinator;
    NAVFeedMock nav;
    TrancheMock tranche;

    ManagerMock mgr;
    VatMock vat;
    SpotterMock spotter;

    Clerk clerk;
    address self;

    function setUp() public {
        currency = new SimpleToken("DAI", "DAI");
        collateral = new SimpleToken("DROP", "DROP");
        
        reserve = new ReserveMock(address(currency));
        assessor = new AssessorMock();
        coordinator = new CoordinatorMock();
        nav = new NAVFeedMock();
        tranche = new TrancheMock();
        mgr = new ManagerMock(address(currency), address(collateral));
        vat = new VatMock();
        spotter = new SpotterMock();

        clerk = new Clerk(address(currency), address(collateral), address(mgr), address(spotter), address(vat));
        clerk.depend("coordinator", address(coordinator));
        clerk.depend("assessor", address(assessor));
        clerk.depend("nav", address(nav));
        clerk.depend("reserve", address(reserve));
        clerk.depend("tranche", address(tranche));

        tranche.depend("token", address(collateral));
        tranche.rely(address(clerk));

        self = address(this);
      
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(block.timestamp);

        // set values for the MKR contracts
        // mat = 110% -> 10% extra security margin required for mkr 
        uint mat = rdiv(rmul(110, ONE), 100);
        spotter.setReturn("mat", mat);
        spotter.setReturn("pip", address(0));
        mgr.setBytes32Return("ilk", "DROP");
        // cdp not in soft liquidation
        mgr.setReturn("safe", true);
    }

    function raise(uint amountDAI) public{
        uint creditlineInit = clerk.creditline();
        uint remainingCreditInit = clerk.remainingCredit();
        uint validateCallsInit = coordinator.calls("validate");
        uint submissionPeriodCallsInit = coordinator.calls("submissionPeriod");
        uint overcollAmount = clerk.calcOvercollAmount(amountDAI);
        uint creditProtection = safeSub(overcollAmount, amountDAI);

        // raise creditLine
        clerk.raise(amountDAI);

        // assert creditLine was increased
        assertEq(clerk.creditline(), safeAdd(creditlineInit, amountDAI));
        // assert remainingCreditLine was also increased
        assertEq(clerk.remainingCredit(), safeAdd(remainingCreditInit, amountDAI));
        // assert call count coordinator & function arguments
        assertEq(coordinator.calls("validate"), safeAdd(validateCallsInit, 1));
        assertEq(coordinator.calls("submissionPeriod"), safeAdd(submissionPeriodCallsInit, 1));    
        assertEq(coordinator.values_uint("seniorSupply"), overcollAmount);
        assertEq(coordinator.values_uint("juniorRedeem"), creditProtection);  
    }

    function draw(uint amountDAI, uint dropPrice) public {
        uint remainingCreditInit = clerk.remainingCredit();
        uint reserveDAIBalanceInit = currency.balanceOf(address(reserve));
        uint collatralBalanceInit = collateral.balanceOf(address(mgr));
        uint juniorStakeInit = clerk.juniorStake();
        uint overcollAmountDAI = clerk.calcOvercollAmount(amountDAI);
        uint protectionAmount = safeSub(overcollAmountDAI, amountDAI);
         // collateral that is required to draw the DAI from the vault -> including mkr extra protection margin
        uint requiredCollateral = rdiv(overcollAmountDAI, dropPrice);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
       
        clerk.draw(amountDAI);

        // make sure remainingCredit decreased by drawAmount
        assertEq(clerk.remainingCredit(), safeSub(remainingCreditInit, amountDAI));
        // make sure reserve DAI balance increased by drawAmount
        assertEq(currency.balanceOf(address(reserve)), safeAdd(reserveDAIBalanceInit, amountDAI));
        // assert DROP collateral amount computed correctly and transferred to cdp
        assertEq(collateral.balanceOf(address(mgr)), safeAdd(collatralBalanceInit, requiredCollateral));
        // assert juniorStake is correct 
        assertEq(clerk.juniorStake(), safeAdd(juniorStakeInit, protectionAmount));

        // for testing increase ink value in vat mock
        vat.setInk(safeAdd(clerk.cdpink(), requiredCollateral));
    }

    function wipe(uint amountDAI, uint dropPrice) public {
        uint tabInit = mgr.cdptab();
        uint reserveDAIBalanceInit = currency.balanceOf(address(reserve));
        uint mgrDAIBalanceInit = currency.balanceOf(address(mgr));   
        uint collLockedInit = collateral.balanceOf(address(mgr));
        uint juniorStakeInit = clerk.juniorStake();
        uint collateralTotalBalanceInit = collateral.totalSupply();
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);

        // repay maker debt
        clerk.wipe(amountDAI);

        // assert that the amount repaid is never higher than the actual debt
        if (amountDAI > tabInit) {
            amountDAI = tabInit;
        }
        // assert DAI were transferred from reserve to mgr
        assertEq(currency.balanceOf(address(mgr)), safeAdd(mgrDAIBalanceInit, amountDAI));
        assertEq(currency.balanceOf(address(reserve)), safeSub(reserveDAIBalanceInit, amountDAI));
        // assert mkr debt reduced 
        assertEq(mgr.cdptab(), safeSub(tabInit, amountDAI));
        // assert remainingCredit is correct
        // remainingCredit can be maximum increased up to creditline value. 
        // Mkr debt can grow bigger then creditline with accrued interest. When repaying mkr debt, make sure that remaining credit never exceeds creditline.
        uint remainingCreditExpected;
        if (mgr.cdptab() > clerk.creditline()) {
            remainingCreditExpected = 0;
        } else {
            remainingCreditExpected = safeSub(clerk.creditline(), mgr.cdptab());
        }
        assertEq(clerk.remainingCredit(), remainingCreditExpected);
        // assert juniorStake was reduced correctly
        (, uint256 mat) = spotter.ilks(mgr.ilk());
        uint juniorStakeReduction = safeSub(rmul(amountDAI, mat), amountDAI);
        assertEq(clerk.juniorStake(), safeSub(juniorStakeInit, juniorStakeReduction));
        // assert collateral amount in cdp correct
        uint collLockedExpected = rdiv(rmul(mgr.cdptab(), mat), dropPrice);
        assertEq(collateral.balanceOf(address(mgr)), collLockedExpected);
        // assert correct amount of collateral burned
        uint collBurnedExpected = safeSub(collLockedInit, collLockedExpected);
        assertEq(collateral.totalSupply(), safeSub(collateralTotalBalanceInit, collBurnedExpected));
        // assert senior asset value decreased by correct amount
        assertEq(assessor.values_uint("changeSeniorAsset_seniorRedeem"), rmul(collBurnedExpected, dropPrice));
        // for testing increase ink value in vat mock
        vat.setInk(collLockedExpected);
    }

    function harvest(uint dropPrice) public {
        uint mgrDAIBalanceInit = currency.balanceOf(address(mgr));   
        uint collLockedInit = collateral.balanceOf(address(mgr));
        uint collateralTotalBalanceInit = collateral.totalSupply();
        (, uint256 mat) = spotter.ilks(mgr.ilk());

        clerk.harvest();
        // assert collateral amount in cdp correct
        uint collLockedExpected = rdiv(rmul(mgr.cdptab(), mat), dropPrice);
        assertEq(collateral.balanceOf(address(mgr)), collLockedExpected);
        // assert correct amount of collateral burned
        uint collBurnedExpected = safeSub(collLockedInit, collLockedExpected);
        assertEq(collateral.totalSupply(), safeSub(collateralTotalBalanceInit, collBurnedExpected));
        // assert senior asset value decreased by correct amount
        assertEq(assessor.values_uint("changeSeniorAsset_seniorRedeem"), rmul(collBurnedExpected, dropPrice));
        // for testing increase ink value in vat mock
        vat.setInk(collLockedExpected);
    }
    
    function sink(uint amountDAI) public {
        uint creditlineInit = clerk.creditline();
        uint remainingCreditInit = clerk.remainingCredit();
        uint validateCallsInit = coordinator.calls("validate");
        uint submissionPeriodCallsInit = coordinator.calls("submissionPeriod");
        uint overcollAmount = clerk.calcOvercollAmount(amountDAI);
        uint creditProtection = safeSub(overcollAmount, amountDAI);

        // raise creditLine
        clerk.sink(amountDAI);
        // assert creditLine was decreased
        assertEq(clerk.creditline(), safeSub(creditlineInit, amountDAI));
        // assert remainingCreditLine was also decreased
        assertEq(clerk.remainingCredit(), safeSub(remainingCreditInit, amountDAI));
        // assert call count coordinator & function arguments
        assertEq(coordinator.calls("validate"), safeAdd(validateCallsInit, 1));
        assertEq(coordinator.calls("submissionPeriod"), safeAdd(submissionPeriodCallsInit, 1));  
        assertEq(coordinator.values_uint("seniorRedeem"), overcollAmount);
        assertEq(coordinator.values_uint("juniorSupply"), creditProtection);  
    }

    function testRaise() public {
        // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validate", 0);
        uint amountDAI = 100 ether;
        // assert calcOvercollAmount computes the correct value
        uint overcollAmountDAI = clerk.calcOvercollAmount(amountDAI);
        assertEq(overcollAmountDAI, 110 ether);
        // assert the security margin is computed correctly 
        uint creditProtection = safeSub(overcollAmountDAI, amountDAI);
        assertEq(creditProtection, 10 ether);

        raise(amountDAI);        
    }

    function testMultipleRaise() public {
        // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validate", 0);
        uint amountDAI = 100 ether;
        // raise 100 DAI
        raise(amountDAI); 
        // raise additional 100 DAI
        raise(amountDAI);     
    }

    function testFailRaiseEpochClosing() public {
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validate", 0);
        uint amountDAI = 100 ether;
        raise(amountDAI);   
    }

    function testFailRaisePoolConstraintsBroken() public {  
       // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to -1 -> failure
        coordinator.setIntReturn("validate", -1);
        uint amountDAI = 100 ether;
        raise(amountDAI);   
    }

    function testFullDraw() public {
        testRaise();
        uint dropPrice = ONE;
        draw(clerk.creditline(), dropPrice);
    }

    function testPartialDraw() public {
        testRaise();
        uint dropPrice = ONE;
        // draw half creditline
        draw(safeDiv(clerk.creditline(), 2), dropPrice);
        // draw another half clerk.creditline()
        draw(safeDiv(clerk.creditline(), 2), dropPrice);
    }

    function testFailDrawAmountTooHigh() public {
        testRaise();
        uint dropPrice = ONE;
        // fail condition: draw amount 1 above credit line
        draw(safeAdd(clerk.creditline(), 1), dropPrice);
    }

    function testFailDrawEpochClosing() public {
        testRaise();
        uint dropPrice = ONE;
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // draw full amount
        draw(clerk.creditline(), dropPrice);
    }

    function testFullWipe() public {
        testFullDraw();
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        mgr.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint tab = mgr.cdptab();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay full debt
        wipe(tab, dropPrice);
    }

    function testPartialWipe() public {
        testFullDraw();
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        mgr.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint tab = mgr.cdptab();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay 1/3 of the debt
        wipe(safeDiv(tab, 2), dropPrice);
        // repay another 1/3 of the debt
        wipe(safeDiv(tab, 4), dropPrice);
    }

    // can not wipe more then total mkr debt
    function testWipeMaxDebt() public {
        testFullDraw();
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        mgr.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint tab = mgr.cdptab();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay full debt
        wipe(rmul(tab, 2), dropPrice);
    }

    function testFailWipeNoDebt() public {
        testFullWipe();
        // try to repay again after full debt already repaid
        wipe(1 ether, ONE);

    }

    function testFailWipeEpochClosing() public {
        testFullDraw();
        // fail condiion: tset submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        mgr.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint tab = mgr.cdptab();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay full debt
        wipe(tab, dropPrice);  
    }

    function testFailWipeNoFundsInReserve() public {
        testFullDraw();
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        mgr.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint tab = mgr.cdptab();
        assertEq(tab, 110 ether);
        // fail conditon: not enough DAI in reserve (only 100 DAI that were drawn before) -> 110 required
        // repay full debt
        wipe(tab, dropPrice);
    }


    function testHarvest() public {
        testFullDraw();
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
        // increase maker debt by 10 DAI
        mgr.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint tab = mgr.cdptab();
        assertEq(tab, 110 ether);
        // harvest junior profit
        // 110 DROP locked -> 220 DAI 
        // 220 DAI - 110 DAI (tab) - 11 (tab protectiom) => 99 DAI junior profit
        harvest(dropPrice);

    }

    function testFailHarvestEpochActive() public {
        testFullDraw();
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
        // increase maker debt by 10 DAI
        mgr.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint tab = mgr.cdptab();
        assertEq(tab, 110 ether);
        // harvest junior profit
        // 110 DROP locked -> 220 DAI 
        // 220 DAI - 110 DAI (tab) - 11 (tab protectiom) => 99 DAI junior profit
        harvest(dropPrice);
        
    }

    function testFailHarvestNoCollateralLocked() public {
        testRaise();
        // increase dropPrice
        uint dropPrice = safeMul(2, ONE);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
        // harvest junior profit
        // 110 DROP locked -> 220 DAI 
        // 220 DAI - 110 DAI (tab) - 11 (tab protectiom) => 99 DAI junior profit
        harvest(dropPrice);
        
    }

    function testFullSink() public {
        testFullWipe();
        uint creditline = clerk.creditline();
        sink(creditline);
    }

    function testPartialSink() public {
        testFullWipe();
        uint creditline = clerk.creditline();
        sink(safeDiv(creditline, 2));
    }

    function testFailSinkAmountTooHigh() public {
        testPartialWipe();
        uint creditline = clerk.creditline();
        sink(creditline);
    }

    function testFailSinkEpochClosing() public {
        testFullWipe();
        uint creditline = clerk.creditline();
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        sink(creditline);

    }
}
