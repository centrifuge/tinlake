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

import "./../base_system.sol";

contract LenderIntegrationTest is BaseSystemTest {
    Hevm public hevm;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        deployLenderMockBorrower(address(this));
        createInvestorUser();
    }

    function testSimpleSeniorOrder() public {
        uint amount = 100 ether;
        currency.mint(address(seniorInvestor), amount);
        // allow senior to hold senior tokens
        seniorMemberlist.updateMember(seniorInvestor_, safeAdd(now, 8 days));
        seniorInvestor.supplyOrder(amount);
        (,uint supplyAmount, ) = seniorTranche.users(seniorInvestor_);
        assertEq(supplyAmount, amount);
        // change order
        seniorInvestor.supplyOrder(amount/2);
        (, supplyAmount, ) = seniorTranche.users(seniorInvestor_);
        assertEq(supplyAmount, amount/2);
    }

    function seniorSupply(uint currencyAmount) public {
        seniorSupply(currencyAmount, seniorInvestor);
    }

    function seniorSupply(uint currencyAmount, Investor investor) public {
        seniorMemberlist.updateMember(seniorInvestor_, safeAdd(now, 8 days));
        currency.mint(address(seniorInvestor), currencyAmount);
        investor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = seniorTranche.users(address(investor));
        assertEq(supplyAmount, currencyAmount);
    }

    function juniorSupply(uint currencyAmount) public {
        juniorMemberlist.updateMember(juniorInvestor_, safeAdd(now, 8 days));
        currency.mint(address(juniorInvestor), currencyAmount);
        juniorInvestor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = juniorTranche.users(juniorInvestor_);
        assertEq(supplyAmount, currencyAmount);
    }

    function testExecuteSimpleEpoch() public {
        uint seniorAmount =  82 ether;
        uint juniorAmount = 18 ether;
        seniorSupply(seniorAmount);
        juniorSupply(juniorAmount);
        hevm.warp(now + 1 days);

        coordinator.closeEpoch();
        // no submission required
        // submission was valid
        assertTrue(coordinator.submissionPeriod() == false);
        // inital token price is ONE
        (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken) = seniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, 0);
        assertEq(payoutTokenAmount, seniorAmount);
        assertEq(seniorToken.balanceOf(seniorInvestor_), seniorAmount);
        assertEq(remainingSupplyCurrency, 0);
        assertEq(remainingRedeemToken, 0);

        // junior
        ( payoutCurrencyAmount,  payoutTokenAmount,  remainingSupplyCurrency,   remainingRedeemToken) = juniorInvestor.disburse();
        assertEq(payoutCurrencyAmount, 0);
        assertEq(payoutTokenAmount, juniorAmount);
        assertEq(juniorToken.balanceOf(juniorInvestor_), juniorAmount);

    }
}

