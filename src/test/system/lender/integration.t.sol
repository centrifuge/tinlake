// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./../base_system.sol";

contract LenderIntegrationTest is BaseSystemTest {

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        deployLenderMockBorrower(address(this));
        createInvestorUser();
    }

    function testAdminPermissions() public {
        assertEq(assessor.wards(address(assessorAdmin)), 1);
        uint newReserve = 200 ether;
        assertEq(assessorAdmin.wards(address(this)), 1);
        assessorAdmin.setMaxReserve(newReserve);
        assertEq(assessor.maxReserve(), newReserve);
    }

    function testSimpleSeniorOrder() public {
        uint amount = 100 ether;
        currency.mint(address(seniorInvestor), amount);
        // allow senior to hold senior tokens
        seniorMemberlist.updateMember(seniorInvestor_, safeAdd(block.timestamp, 8 days));
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
        seniorMemberlist.updateMember(seniorInvestor_, safeAdd(block.timestamp, 8 days));
        currency.mint(address(seniorInvestor), currencyAmount);
        investor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = seniorTranche.users(address(investor));
        assertEq(supplyAmount, currencyAmount);
    }

    function juniorSupply(uint currencyAmount) public {
        juniorMemberlist.updateMember(juniorInvestor_, safeAdd(block.timestamp, 8 days));
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
        hevm.warp(block.timestamp + 1 days);

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

