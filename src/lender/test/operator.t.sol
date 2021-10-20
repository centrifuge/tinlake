// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";

import "./mock/tranche.sol";
import "../operator.sol";
import "../token/restricted.sol";
import "../token/memberlist.sol";
import "tinlake-math/math.sol";


contract OperatorTest is Math, DSTest {

    uint memberlistValidity = safeAdd(block.timestamp, 8 days);
    TrancheMock tranche;
    Operator operator;
    Memberlist memberlist;
    RestrictedToken token;

    address self;
    address operator_;

    function setUp() public {
        tranche = new TrancheMock();
        memberlist = new Memberlist();
        token = new RestrictedToken("TST", "TST");
        token.depend("memberlist", address(memberlist));

        operator = new Operator(address(tranche));
        operator.depend("token", address(token));

        self = address(this);
        operator_ = address(operator);
    }

    function testSupplyOrder() public {
        uint amount = 10;

        // rely operator on tranche
        tranche.rely(operator_);
        // add investor to token memberlist
        memberlist.updateMember(self, safeAdd(block.timestamp, memberlistValidity));
        operator.supplyOrder(amount);

        assertEq(tranche.calls("supplyOrder"), 1);
        assertEq(tranche.values_address("supply_usr"), self);
        assertEq(tranche.values_uint("supplyAmount"), amount);
    }

    function testFailSupplyOrderNotMember() public {
        uint amount = 10;

        // rely operator on tranche
        tranche.rely(operator_);
        operator.supplyOrder(amount);
    }

    function testFailSupplyOrderOperatorNotWard() public {
        uint amount = 10;
        // add investor to memberlist of tokenholders
        memberlist.updateMember(self, safeAdd(block.timestamp, memberlistValidity));
        operator.supplyOrder(amount);
    }

    function testRedeemOrder() public {
        uint amount = 10;
        // rely operator on tranche
        tranche.rely(operator_);
        // add investor to memberlist of tokenholders
        memberlist.updateMember(self, safeAdd(block.timestamp, memberlistValidity));
        operator.redeemOrder(amount);

        assertEq(tranche.calls("redeemOrder"), 1);
        assertEq(tranche.values_address("redeem_usr"), self);
        assertEq(tranche.values_uint("redeemAmount"), amount);
    }

    function testFailRedeemOrderNotMember() public {
        uint amount = 10;
        // rely operator on tranche
        tranche.rely(operator_);
        operator.redeemOrder(amount);
    }

    function testFailRedeemOrderOperatorNotWard() public {
        uint amount = 10;
       // add investor to memberlist of tokenholders
        memberlist.updateMember(self, safeAdd(block.timestamp, memberlistValidity));
        operator.redeemOrder(amount);
    }

    function testDisburse() public {
        // rely operator on tranche
        tranche.rely(operator_);
        // add investor to memberlist of tokenholders
        memberlist.updateMember(self, safeAdd(block.timestamp, memberlistValidity));

        operator.disburse();

        assertEq(tranche.calls("disburse"), 1);
        assertEq(tranche.values_address("disburse_usr"), self);
    }

    function testFailDisburseNotMember() public {
        // rely operator on tranche
        tranche.rely(operator_);

        operator.disburse();
    }

    function testFailDisburseOperatorNotWard() public {
       // add investor to memberlist of tokenholders
        memberlist.updateMember(self, safeAdd(block.timestamp, memberlistValidity));

        operator.disburse();
    }

}
