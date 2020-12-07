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
        mgr = new ManagerMock();
        vat = new VatMock();
        spotter = new SpotterMock();

        clerk = new Clerk(address(currency), address(collateral), address(mgr), address(spotter), address(vat));
        clerk.depend("coordinator", address(coordinator));
        clerk.depend("assessor", address(assessor));
        clerk.depend("nav", address(nav));
        clerk.depend("reserve", address(reserve));
        clerk.depend("tranche", address(tranche));

        self = address(this);
      
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(block.timestamp);
    }

    function testRaise() public {
        bytes32 ilkId = "DROP";
        uint creditIncrease = 100 ether;
        // extra mkr protection ratio = 110 %
        uint mat = rdiv(rmul(110, ONE), 100);

        // set mkr debt to 0
        mgr.setReturn("tab", 0);
        // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validate", 0);
        // set mat value in spotter 
        spotter.setReturn("pip", address(0));
        spotter.setReturn("mat", mat);
        // set ilkId in mgr
        mgr.setBytes32Return("ilk", ilkId);

        // raise creditLine
        clerk.raise(creditIncrease);

        // assert creditLine was increased
        assertEq(clerk.creditline(), creditIncrease);
        // assert remainingCreditLine was also increased
        assertEq(clerk.remainingCredit(), creditIncrease);
        uint overcollAmount = clerk.calcOvercollAmount(creditIncrease);
        // assert that the overcollateralized amountDAI is correct
        assertEq(overcollAmount, 110 ether);
         // assert that creditProtection amount is correct
        uint creditProtection = safeSub(overcollAmount, creditIncrease);
        assertEq(creditProtection, 10 ether);

        // check call count coordinator & function arguments
        assertEq(coordinator.calls("validate"), 1);
        assertEq(coordinator.values_uint("seniorSupply"), overcollAmount);
        assertEq(coordinator.values_uint("juniorRedeem"), creditProtection);
         // check validation was called with correct values 
        assertEq(coordinator.calls("submissionPeriod"), 1);    
    }

    function testFailRaiseEpochClosing() public {
        bytes32 ilkId = "DROP";
        uint creditIncrease = 100 ether;
        // extra mkr protection ratio = 110 %
        uint mat = rdiv(rmul(110, ONE), 100);

        // set mkr debt to 0
        mgr.setReturn("tab", 0);
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validate", 0);
        // set mat value in spotter 
        spotter.setReturn("pip", address(0));
        spotter.setReturn("mat", mat);
        // set ilkId in mgr
        mgr.setBytes32Return("ilk", ilkId);

        // raise creditLine
        clerk.raise(creditIncrease);
    }

    function testFailPoolConstraintsBroken() public {  
                bytes32 ilkId = "DROP";
        uint creditIncrease = 100 ether;
        // extra mkr protection ratio = 110 %
        uint mat = rdiv(rmul(110, ONE), 100);

        // set mkr debt to 0
        mgr.setReturn("tab", 0);
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validate", -1);
        // set mat value in spotter 
        spotter.setReturn("pip", address(0));
        spotter.setReturn("mat", mat);
        // set ilkId in mgr
        mgr.setBytes32Return("ilk", ilkId);

        // raise creditLine
        clerk.raise(creditIncrease);  
    }

    function testDraw() public {
    }
    function testWipe() public {
    }
    function testSink() public {
    }
    function testHarvest() public {
    }
}
