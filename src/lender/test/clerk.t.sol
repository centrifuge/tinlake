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
        // check call count coordinator & function arguments
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
        // assessor: set DROP token price to
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
       
        clerk.draw(amountDAI);

        // make sure remainingCredit decreased by drawAmount
        assertEq(clerk.remainingCredit(), safeSub(remainingCreditInit, amountDAI));
        // make sure reserve DAI balance increased by drawAmount
        assertEq(currency.balanceOf(address(reserve)), safeAdd(reserveDAIBalanceInit, amountDAI));
        // check DROP collateral amount computed correctly and transferred to cdp
        assertEq(collateral.balanceOf(address(mgr)), safeAdd(collatralBalanceInit, requiredCollateral));
        // check if juniorStake is correct 
        assertEq(clerk.juniorStake(), safeAdd(juniorStakeInit, protectionAmount));
    }

    function testRaise() public {
        // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validate", 0);
        uint amountDAI = 100 ether;
        // check if calcOvercollAmount computes the correct value
        uint overcollAmountDAI = clerk.calcOvercollAmount(amountDAI);
        assertEq(overcollAmountDAI, 110 ether);
        // check if the security margin is computed correclty 
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

    function testFailPoolConstraintsBroken() public {  
       // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to -1 -> failure
        coordinator.setIntReturn("validate", -1);
        uint amountDAI = 100 ether;
        raise(amountDAI);   
    }

    function testFullDraw() public {
        uint creditline = 100 ether;
        uint dropPrice = ONE;
        // increase creditline
        raise(creditline);
        // draw full amount
        draw(creditline, dropPrice);
    }

    function testMultipleDraw() public {
        uint creditline = 100 ether;
        uint dropPrice = ONE;
        // increase creditline
        raise(creditline);
        // draw half creditline
        draw(safeDiv(creditline, 2), dropPrice);
        // draw another half creditline
        draw(safeDiv(creditline, 2), dropPrice);
    }

    function testFailDrawAmountTooHigh() public {
        uint creditline = 100 ether;
        uint dropPrice = ONE;
        // increase creditline
        raise(creditline);
        // fail condition: draw amount 1 above credit line
        draw(safeAdd(creditline, 1), dropPrice);
    }

    function testFailDrawEpochClosing() public {
        uint creditline = 100 ether;
        uint dropPrice = ONE;
        // increase creditline
        raise(creditline);
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // draw full amount
        draw(creditline, dropPrice);
    }

    function testFullWipe() public {}
    function testPartialWipe() public {}
    function testFullSink() public {}
    function testPartialSink() public {}
    function testHarvest() public {}
}
