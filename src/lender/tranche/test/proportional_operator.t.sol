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

import "../../test/mock/tranche.sol";
import "../../test/mock/assessor.sol";
import "../../test/mock/distributor.sol";

import "./../operator/proportional.sol";
import "./investor.t.sol";

contract ProportionalOperatorTest is DSTest {
    uint256 constant ONE = 10 ** 27;

    AssessorMock assessor;
    TrancheMock tranche;
    DistributorMock distributor;
    ProportionalOperator operator;
    address operator_;

    Investor investorA;
    Investor investorB;

    function setUp() public {
        assessor =  new AssessorMock();
        assessor.setReturn("tokenPrice", ONE);
        assessor.setReturn("supplyApprove", true);
        assessor.setReturn("redeemApprove", true);

        tranche = new TrancheMock();

        investorA = new Investor();
        investorB = new Investor();

        distributor = new DistributorMock();
        operator = new ProportionalOperator(address(tranche), address(assessor), address(distributor));
        operator_ = address(operator);

        operator.depend("tranche", address(tranche));
}

    // basic tests
    function testApproveSupply() public {
        uint amount = 100 ether;
        operator.approve(address(investorA), amount);
        investorA.doSupply(operator_, amount);
        assertEq(tranche.calls("supply"), 1);
        assertEq(tranche.values_uint("supply_currencyAmount"), amount);
    }

    function testUpdateReturn() public {
        uint currencyReturned = 110 ether;
        uint principalReturned = 100 ether;
        operator.updateReturned(currencyReturned, principalReturned);
        assertEq(operator.totalCurrencyReturned(), currencyReturned);
        assertEq(operator.totalPrincipalReturned(), principalReturned);

        operator.updateReturned(currencyReturned, principalReturned);
        assertEq(operator.totalCurrencyReturned(), currencyReturned*2);
        assertEq(operator.totalPrincipalReturned(), principalReturned*2);
    }

    function testFailSupplyTooMuch() public {
        uint amount = 100 ether;
        operator.approve(address(investorA), amount);
        investorA.doSupply(operator_, amount + 1);
    }

    function supplyInvestor(Investor investor, uint amount) internal {
        operator.approve(address(investor), amount);
        investor.doSupply(operator_, amount );
    }

    function testMaxRedeemToken() public {
        supplyInvestor(investorA, 100 ether);
        supplyInvestor(investorB, 100 ether);
        assertEq(operator.calcMaxRedeemToken(address(investorA)), 0);

        // start redeem
        uint totalSupply = 200 ether;
        tranche.setReturn("tokenSupply", totalSupply);
        operator.file("supplyAllowed", false);
        uint currencyReturned = 105 ether;
        uint principalReturned = 100 ether;
        operator.updateReturned(currencyReturned, principalReturned);
        assertEq(operator.calcMaxRedeemToken(address(investorA)), 50 ether);
    }

    function testSimpleRedeem() public {
        supplyInvestor(investorA, 100 ether);
        supplyInvestor(investorB, 100 ether);
        assertEq(operator.calcMaxRedeemToken(address(investorA)), 0);

        // start redeem
        uint totalSupply = 200 ether;
        tranche.setReturn("tokenSupply", totalSupply);

        // max redeem should be 50 ether
        assertEq(operator.calcMaxRedeemToken(address(investorA)), 50 ether);

    }
}


