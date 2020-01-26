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

pragma solidity >=0.5.12;

import "../../base_system.sol";

contract DefaultInterestAssessorTest is BaseSystemTest {

    Hevm hevm;

    TAssessorLike assessor;

    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bytes32 assessor_ = "default";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_,assessor_, deploySeniorTranche);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        assessor = TAssessorLike(address(lenderDeployer.assessor()));

        createTestUsers(deploySeniorTranche);
    }

    function testBasicSetupWithSupplyRedeem() public {
        uint seniorInvestorAmount = 100 ether;
        uint juniorInvestorAmount = 200 ether;
        supplySenior(seniorInvestorAmount);
        supplyJunior(juniorInvestorAmount);

        // currency equals token amount
        seniorInvestor.doRedeem(seniorInvestorAmount);
        juniorInvestor.doRedeem(juniorInvestorAmount);

    }

    function testSeniorInterest() public {
        // interest per day of senior tranche is 5%
        uint amount = 100 ether;

        // total in tranches: 200 ether
        supplySenior(amount);
        supplyJunior(amount);

        // case no interest: no loans borrowed
        assertEq(senior.debt(), 0 ether);
        supplySenior(amount);
        hevm.warp(now + 1 days);
        senior.drip();
        assertEq(senior.interest(), 0 ether);

        // case no interest: only junior borrowed
        (uint loan, ) = createLoanAndWithdraw(borrower_, 80 ether);
        assertEq(senior.borrowed(), 0 ether);

        hevm.warp(now + 1 days);
        senior.drip();
        assertEq(senior.interest(), 0 ether);

        // case make interest: on senior debt of 10 ether
        createLoanAndWithdraw(borrower_, 30 ether);
        assertEq(senior.borrowed(), 10 ether);

        hevm.warp(now + 1 days);
        senior.drip();
        // interest on 10 ether borrowed
        assertEq(senior.interest(), 0.5 ether); // 10 * 1.05 = 10.5 ether

        assertEq(senior.debt(), 10.5 ether);
        // partial borrow of first loan
        // first interest
        repayLoan(borrower_, loan, 0.5 ether);
        assertEq(senior.interest(), 0 ether);
        assertEq(senior.debt(), 10 ether);
        // partial repay to reduce senior debt to 0
        repayLoan(borrower_, loan, 10 ether);
        assertEq(senior.debt(), 0 ether);

        hevm.warp(now + 1 days);
        senior.drip();
        // no new interest for senior
        assertEq(senior.interest(), 0 ether);

    }

    function testRedeemInvestmentWithInterest() public {
        uint amount = 100 ether;
        uint total = 200 ether;

        // total in tranches: 200 ether
        supplySenior(amount);
        supplyJunior(amount);

        // + 5 ether interest for senior
        (uint loan, ) = createLoanAndWithdraw(borrower_, total);
        assertEq(senior.borrowed(), 100 ether);
        hevm.warp(now + 1 days);
        repayLoan(borrower_, loan, total);
        assertEq(senior.balance(), amount + 5 ether);

        // senior: 100 token for 105 currency
        uint seniorToken = 100 ether;
        seniorInvestor.doRedeem(seniorToken);
        assertEq(currency.balanceOf(seniorInvestor_), 105 ether);

        // junior 100 token for 95 currency
        uint juniorToken = 100 ether;
        juniorInvestor.doRedeem(juniorToken);
        assertEq(currency.balanceOf(juniorInvestor_), 95 ether);
    }

}