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

contract FullInterestAssessorTest is BaseSystemTest {

    Hevm hevm;

    TAssessorLike assessor;

    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bytes32 assessor_ = "full_investment";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_,assessor_, deploySeniorTranche);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        assessor = TAssessorLike(address(lenderDeployer.assessor()));

        createTestUsers(deploySeniorTranche);
    }

    function supplySenior(uint amount) public {
        currency.mint(seniorInvestor_, amount);
        seniorInvestor.doSupply(amount);
    }

    function supplyJunior(uint amount) public {
        currency.mint(juniorInvestor_, amount);

        juniorInvestor.doSupply(amount);
        // currency in tranche
        assertEq(currency.balanceOf(address(lenderDeployer.junior())), amount);
        // junior investor has token
        assertEq(juniorToken.balanceOf(juniorInvestor_), amount);
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
        supplySenior(amount);

        assertEq(senior.debt(), 0 ether);
        hevm.warp(now + 1 days);
        senior.drip();

        assertEq(senior.interest(), 5 ether);
        hevm.warp(now + 1 days);
        senior.drip();
        assertEq(senior.interest(), 10.25 ether);
        assertEq(senior.borrowed(), 0);

        // additional investment
        uint secondAmount = 100 ether;
        currency.mint(seniorInvestor_, secondAmount);
        seniorInvestor.doSupply(secondAmount);

        // interest should stay the same
        assertEq(senior.interest(), 10.25 ether);
        assertEq(senior.borrowed(), 0);

        hevm.warp(now + 1 days);

        assertEq(senior.balance(), 200 ether);
        assertEq(senior.interest(), 10.25 ether);
        assertEq(senior.borrowed(), 0);

        // interestBearingAmount 210.25 * 1.05 = 220.7625
        // delta interest: 5.2625
        uint interestDelta = assessor.accrueTrancheInterest(address(senior));
        assertEq(interestDelta, 10.5125 ether);

        senior.drip();
        assertEq(senior.balance(), 200 ether);
        assertEq(senior.borrowed(), 0);

        assertEq(senior.interest(), 10.25 ether + interestDelta);

    }

    function testRedeemInvestmentWithInterest() public {
        // interest per day of senior tranche is 5%
        uint amount = 100 ether;
        supplySenior(amount);
        supplyJunior(amount);

        // no loans senior will get currency from junior
        hevm.warp(now + 1 days);
        senior.drip();
        assertEq(senior.interest(), 5 ether);


        // senior: 100 token for 105 currency
        uint seniorToken = 100 ether;
        seniorInvestor.doRedeem(seniorToken);
        assertEq(currency.balanceOf(seniorInvestor_), 105 ether);


        // junior 100 token for 95 currency
        uint juniorToken = 100 ether;
        juniorInvestor.doRedeem(juniorToken);
        assertEq(currency.balanceOf(juniorInvestor_), 95 ether);
    }

    function testTrancheInterestWithLoans() public {
        // interest per day of senior tranche is 5%
        uint amount = 100 ether;
        supplySenior(amount);

        assertEq(senior.debt(), 0 ether);

        // loan borrowed (only senior has currency)
        // should have no impact on interest calc
        (uint loan, ) = createLoanAndWithdraw(borrower_, 80 ether);
        assertEq(senior.borrowed(), 80 ether);
        assertEq(senior.balance(), 20 ether);

        // one day later
        hevm.warp(now + 1 days);
        senior.drip();

        assertEq(senior.interest(), 5 ether);

        // repayment
        repayLoan(borrower_, loan, 80 ether);
        assertEq(senior.balance(), 100 ether);
        // interest is repaid first
        assertEq(senior.interest(), 0 ether);
        assertEq(senior.borrowed(), 5 ether);

        hevm.warp(now + 1 days);
        senior.drip();
        assertEq(senior.interest(), 5.25 ether);

    }
}