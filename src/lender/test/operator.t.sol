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

import "./mock/tranche.sol";
import "../operator.sol";


contract OperatorTest is DSTest {

    uint256 constant ONE = 10 ** 27;

    TrancheMock tranche;
    Operator operator;

    address self;
    address operator_;

    function setUp() public {
        tranche = new TrancheMock();
        operator = new Operator(address(tranche));
        self = address(this);
        operator_ = address(operator);
    }

    function testAddInvestorToMemberList() public {
        operator.relyInvestor(self);
        assertEq(operator.investors(self), 1);
    }

    function testSupplyOrder() public {
        uint epochID = 3;
        uint amount = 10;

        // rely operator on tranche
        tranche.rely(operator_);
        // rely address (investor) on operator
        operator.relyInvestor(self);
        operator.supplyOrder(epochID, amount);
    
        assertEq(tranche.calls("supplyOrder"), 1);
        assertEq(tranche.values_address("supply_usr"), self);
        assertEq(tranche.values_uint("supply_epochID"), epochID);
        assertEq(tranche.values_uint("supplyAmount"), amount);
    }

    function testFailSupplyOrderNotMember() public {
        uint epochID = 3;
        uint amount = 10;

        // rely operator on tranche
        tranche.rely(operator_);
        
        operator.supplyOrder(epochID, amount);
    }

    function testFailSupplyOrderOperatorNotWard() public {
        uint epochID = 3;
        uint amount = 10;
        // rely address (investor) on operator
        operator.relyInvestor(self);
        operator.supplyOrder(epochID, amount);
    }

    function testRedeemOrder() public {
        uint epochID = 3;
        uint amount = 10;

        // rely operator on tranche
        tranche.rely(operator_);
        // rely address (investor) on operator
        operator.relyInvestor(self);
        operator.redeemOrder(epochID, amount);
    
        assertEq(tranche.calls("redeemOrder"), 1);
        assertEq(tranche.values_address("redeem_usr"), self);
        assertEq(tranche.values_uint("redeem_epochID"), epochID);
        assertEq(tranche.values_uint("redeemAmount"), amount);
    }

    function testFailRedeemOrderNotMember() public {
        uint epochID = 3;
        uint amount = 10;

        // rely operator on tranche
        tranche.rely(operator_);
       
        operator.redeemOrder(epochID, amount);        
    }

    function testFailRedeemOrderOperatorNotWard() public {
        uint epochID = 3;
        uint amount = 10;
        // rely address (investor) on operator
        operator.relyInvestor(self);
        operator.redeemOrder(epochID, amount);
    }

    function testDisburse() public {
        uint epochID = 3;
        // rely operator on tranche
        tranche.rely(operator_);
        // rely address (investor) on operator
        operator.relyInvestor(self);
        
        operator.disburse(epochID);
    
        assertEq(tranche.calls("disburse"), 1);
        assertEq(tranche.values_address("disburse_usr"), self);
        assertEq(tranche.values_uint("disburse_epochID"), epochID);
    }

    function testFailDisburseNotMember() public {
        uint epochID = 3;
        // rely operator on tranche
        tranche.rely(operator_);
        
        operator.disburse(epochID);
    }

    function testFailDisburseOperatorNotWard() public {
        uint epochID = 3;
        // rely address (investor) on operator
        operator.relyInvestor(self);
        
        operator.disburse(epochID);
    }

}