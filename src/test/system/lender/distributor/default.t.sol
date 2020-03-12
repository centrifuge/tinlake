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

pragma solidity >=0.5.3;

import "../../base_system.sol";

contract SupplyTwoTrancheTest is BaseSystemTest {

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

    function setUpDebtScenario(uint seniorAmount, uint juniorAmount, uint loanAmount) public returns(uint) {
        // set up tranches
        supplySenior(seniorAmount);
        supplyJunior(juniorAmount);

        // currency for loan borrowed from both tranches
        (uint loan, ) = createLoanAndWithdraw(borrower_, loanAmount);
        return loan;
    }

    function testBalanceFromJuniorToSenior() public {
        uint seniorAmount = 200 ether; uint juniorAmount = 50 ether;
        uint loanAmount = 100 ether;
        setUpDebtScenario(seniorAmount, juniorAmount, loanAmount);

        uint seniorDebt = 50 ether;
        assertEq(senior.updatedDebt(), seniorDebt);

        // additional supply in junior should call distributor.balance
        // 50 ether: junior -> distributor -> senior
        supplyJunior(60 ether);


        assertEq(senior.updatedDebt(), 0 ether);
        assertEq(junior.balance(), 10 ether);
    }

    function testRepaySeniorFist() public {
        uint seniorAmount = 200 ether; uint juniorAmount = 50 ether;
        uint loanAmount = 100 ether;
        uint loan = setUpDebtScenario(seniorAmount, juniorAmount, loanAmount);

        uint seniorDebt = 50 ether;
        assertEq(senior.updatedDebt(), seniorDebt);

        repayLoan(borrower_, loan, 60 ether);

        assertEq(senior.updatedDebt(), 0 ether);
        assertEq(senior.balance(), seniorAmount);
        assertEq(junior.balance(), 10 ether);
    }

    function testRepayOnlyJunior() public {
        uint seniorAmount = 200 ether; uint juniorAmount = 50 ether;
        uint loanAmount = 50 ether;
        uint loan = setUpDebtScenario(seniorAmount, juniorAmount, loanAmount);

        uint seniorDebt = 0;
        assertEq(senior.updatedDebt(), seniorDebt);

        assertEq(junior.balance(), 0);

        // only junior repay no senior debt
        repayLoan(borrower_, loan, 50 ether);
        assertEq(junior.balance(), 50 ether);
    }

    function testRepayOnlySenior() public {
        uint seniorAmount = 200 ether; uint juniorAmount = 50 ether;
        uint loanAmount = 100 ether;
        uint loan = setUpDebtScenario(seniorAmount, juniorAmount, loanAmount);

        uint seniorDebt = 50 ether;
        assertEq(senior.updatedDebt(), seniorDebt);
        assertEq(junior.balance(), 0);

        // repay only senior
        repayLoan(borrower_, loan, 50 ether);

        assertEq(junior.balance(), 0);
        assertEq(senior.updatedDebt(), 0);

    }
}
