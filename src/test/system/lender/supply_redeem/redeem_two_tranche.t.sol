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

contract FileLike {
    function file(bytes32, uint) public;
}

contract RedeemTwoTrancheTest is BaseSystemTest {

    Hevm hevm;

    function setUp() public {

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bool deploySeniorTranche = true;

        baseSetup(operator_, distributor_, deploySeniorTranche);
        createTestUsers(deploySeniorTranche);
    }

    function testSimpleRedeem() public {
        uint jSupplyAmount = 40 ether;
        uint sSupplyAmount = 160 ether;

        topUp(juniorInvestor_);
        topUp(seniorInvestor_);

        uint minJuniorRatio = 2 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        // new loan, should take all from junior and 60 from senior
        uint ceiling = 100 ether;
        uint rate = 1000000564701133626865910626; // 5% per day compound in seconds
        uint speed = rate;
        (uint loanId,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        assertEq(currency.balanceOf(address(borrower)), 100 ether);
        assertEq(currency.balanceOf(address(junior)), 0);
        assertEq(currency.balanceOf(address(senior)), 100 ether);
        assertEq(senior.debt(), 60 ether);

        hevm.warp(now + 1 days);

        // senior rate: 5% a day: 60 * 1.05 = 63
        uint seniorDebt = senior.debt();
        assertEq(seniorDebt, 63 ether);

        repayLoan(borrower_, loanId, seniorDebt + jSupplyAmount);
        assertEq(senior.debt(), 0);

        seniorInvestor.doRedeem(sSupplyAmount);
        assertEq(currency.balanceOf(address(junior)), jSupplyAmount);
        assertEq(currency.balanceOf(address(senior)), 0);
        juniorInvestor.doRedeem(5 ether);
        // junior cannot redeem all jSupplyAmount without breaking minJuniorRatio, so it has to first supply more currency
        juniorInvestor.doSupply(jSupplyAmount);
        juniorInvestor.doRedeem(jSupplyAmount);
    }

    function testFailSimpleRedeem() public {
        uint jSupplyAmount = 40 ether;
        uint sSupplyAmount = 160 ether;

        topUp(juniorInvestor_);
        topUp(seniorInvestor_);

        uint minJuniorRatio = 2 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        // new loan, should take all from junior and 60 from senior
        uint ceiling = 100 ether;
        uint rate = 1000000564701133626865910626; // 5% per day compound in seconds
        uint speed = rate;
        (uint loanId,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        hevm.warp(now + 1 days);

        uint seniorDebt = senior.debt();
        assertEq(seniorDebt, 63 ether);

        repayLoan(borrower_, loanId, seniorDebt + jSupplyAmount);
        // junior redeem will break the minJuniorRatio
        juniorInvestor.doRedeem(jSupplyAmount);
    }

    function testRedeemWithDefaults() public {
        uint jSupplyAmount = 50 ether;
        uint sSupplyAmount = 200 ether;

        supplyFunds(sSupplyAmount, seniorInvestor_);
        supplyFunds(jSupplyAmount, juniorInvestor_);

        uint minJuniorRatio = 2 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        // new loan, should take all from junior and 50 from senior
        uint ceiling = 100 ether;
        uint rate = 1000000564701133626865910626; // 5% per day compound in seconds
        uint speed = rate;
        (uint loanA,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        // new loan, should take 100 from senior
        (uint loanB,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        hevm.warp(now + 5 days);
        // 5% senior rate with an interestBearingAmount of 150 ether
        assertEq(senior.debt(), 191.442234375 ether);

        // loan B has defaulted
        uint threshold = 115 ether;
        uint recoveryPrice = 75 ether;
        addKeeperAndCollect(loanB, threshold, borrower_, recoveryPrice);
        // 75 recovery price + 50 ether reserve
        assertEq(currency.balanceOf(address(senior)), 125 ether);

        // 100 * 1.05^5 = 127.62815625
        uint loanDebt = 127.62815625 ether;
        repayLoan(borrower_, loanA, loanDebt);

        seniorInvestor.doRedeem(sSupplyAmount);
        assertEq(senior.debt(), 0);
        // 150 * (1.05^5) = 191.442234375 (41.442234375 ether profit)
        // total received tranche repayment: 202.62815625 ether (first loan: 75 ether, second loan: 127.62815625 ether)
        // senior receives 191.442234375 for the debt (debt entirely repaid)
        // junior repayment: 202.62815625 ether - 191.442234375 ether = 11.185921875 ether

        // balance should be initial investment = 200 ether  + profit
        uint expectedSeniorBalance = 241.442234375 ether;
        assertEq(currency.balanceOf(seniorInvestor_), expectedSeniorBalance);
        juniorInvestor.doRedeem(jSupplyAmount);
        // 63.814078125 ether was the expected profit from the junior tranche (total loans amount: 200 * 1.05^5 - seniorDebt = 63.814078125 ether)
        // 63.814078125 ether - the 52.62815625 ether missing from the recovered defaulted loan = 11.185921875
        uint expectedJuniorBalance = 11.185921875 ether;
        assertEq(currency.balanceOf(juniorInvestor_), expectedJuniorBalance);
    }

    function testFailRedeemWithDefaults() public {
        uint jSupplyAmount = 50 ether;
        uint sSupplyAmount = 200 ether;

        supplyFunds(sSupplyAmount, seniorInvestor_);
        supplyFunds(jSupplyAmount, juniorInvestor_);

        uint minJuniorRatio = 2 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        // new loan, should take all from junior and 50 from senior
        uint ceiling = 100 ether;
        uint rate = 1000000564701133626865910626; // 5% per day compound in seconds
        uint speed = rate;
        (uint loanA,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        // new loan, should take 100 from senior
        (uint loanB,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        hevm.warp(now + 5 days);

        // senior debt = 191.442234375 ether

        // loanB has defaulted
        uint threshold = 115 ether;
        uint recoveryPrice = 25 ether;
        addKeeperAndCollect(loanB, threshold, borrower_, recoveryPrice);

        // senior balance is 75 ether: 25 recovery price + 50 ether reserve

        uint loanDebt = 127.62815625 ether;
        repayLoan(borrower_, loanA, loanDebt);
        seniorInvestor.doRedeem(sSupplyAmount);
        assertEq(senior.debt(), 38.814078125 ether);

        // 150 * (1.05^5) = 191.442234375, 41.442234375 ether profit
        // profit must take into account still unpaid debt, 41.442234375 - 38.814078125 = 2.62815625
        // balance of senior investor is 202.62815625 ether
        // juniorInvestor cannot redeem
        juniorInvestor.doRedeem(jSupplyAmount);
    }
}
