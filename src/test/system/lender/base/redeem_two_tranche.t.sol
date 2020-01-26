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

    function supply(uint balance, uint amount) public {
        currency.mint(juniorInvestor_, balance);
        juniorInvestor.doSupply(amount);
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

        // new loan, should take all from junior and 26 from senior
        uint ceiling = 100 ether;
        uint rate = 1000000564701133626865910626; // 5% per day compound in seconds
        uint speed = rate;
        (uint loanId,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        assertEq(currency.balanceOf(address(borrower)), 100 ether);
        assertEq(currency.balanceOf(address(junior)), 0);
        assertEq(currency.balanceOf(address(senior)), 100 ether);
        assertEq(senior.debt(), 60 ether);

        hevm.warp(now + 1 days);

        uint seniorDebt = senior.debt();
        assertEq(seniorDebt, 63 ether);

        repayLoan(borrower_, loanId, seniorDebt + jSupplyAmount);
        seniorInvestor.doRedeem(seniorDebt);
        assertEq(senior.debt(), 0);
        assertEq(currency.balanceOf(address(junior)), jSupplyAmount);
        // junior cannot redeem without breaking minJuniorRatio, so it has to first supply more currency
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

        // new loan, should take all from junior and 26 from senior
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

        topUp(juniorInvestor_);
        topUp(seniorInvestor_);
        topUp(admin_);

        uint minJuniorRatio = 2 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        emit log_named_uint("balance",currency.balanceOf(seniorInvestor_));


        // new loan, should take all from junior and 50 from senior
        uint ceiling = 100 ether;
        uint rate = 1000000564701133626865910626; // 5% per day compound in seconds
        uint speed = rate;
        (uint loanA,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        // new loan, should take 100 from senior
        (uint loanB,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        hevm.warp(now + 5 days);
        assertEq(senior.debt(), 191.442234375 ether);

        // loanB has defaulted
        uint threshold = 115 ether;
        uint recoveryPrice = 75 ether;
        addKeeperAndCollect(loanB, threshold, borrower_, recoveryPrice);
        // 75 recovery price + 50 ether reserve
        assertEq(currency.balanceOf(address(senior)), 125 ether);

        uint loanDebt = 127.62815625 ether;
        repayLoan(borrower_, loanA, loanDebt);
        seniorInvestor.doRedeem(sSupplyAmount);
        emit log_named_uint("balance",currency.balanceOf(seniorInvestor_));
        assertEq(senior.debt(), 0);
        // 150 * (1.05^5) = 191.442234375, 41.442234375 ether profit
        assertEq(currency.balanceOf(seniorInvestor_), 1041.442234375 ether);

        juniorInvestor.doRedeem(jSupplyAmount);
        //63.814078125 ether was the junior expected profit but junior takes the losses
        //63.814078125 ether - the 52.62815625 ether missing from the recovered defaulted loan = 11.185921875
        assertEq(currency.balanceOf(juniorInvestor_), 961.185921875 ether);
    }

    function testRedeemWith() public {
        uint jSupplyAmount = 50 ether;
        uint sSupplyAmount = 200 ether;

        topUp(juniorInvestor_);
        topUp(seniorInvestor_);
        topUp(admin_);

        uint minJuniorRatio = 2 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        emit log_named_uint("balance",currency.balanceOf(seniorInvestor_));


        // new loan, should take all from junior and 50 from senior
        uint ceiling = 100 ether;
        uint rate = 1000000564701133626865910626; // 5% per day compound in seconds
        uint speed = rate;
        (uint loanA,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        // new loan, should take 100 from senior
        (uint loanB,) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);

        hevm.warp(now + 5 days);
        assertEq(senior.debt(), 191.442234375 ether);

        // loanB has defaulted
        uint threshold = 115 ether;
        uint recoveryPrice = 25 ether;
        addKeeperAndCollect(loanB, threshold, borrower_, recoveryPrice);
        // 25 recovery price + 50 ether reserve
        assertEq(currency.balanceOf(address(senior)), 75 ether);

        uint loanDebt = 127.62815625 ether;
        repayLoan(borrower_, loanA, loanDebt);
        seniorInvestor.doRedeem(sSupplyAmount);
        emit log_named_uint("balance",currency.balanceOf(seniorInvestor_));
        assertEq(senior.debt(), 38.814078125 ether);
        // 150 * (1.05^5) = 191.442234375, 41.442234375 ether profit
        // profit must take into account still unpaid debt, 41.442234375 - 38.814078125 = 2.62815625
        assertEq(currency.balanceOf(seniorInvestor_), 1002.62815625 ether);
        // juniorInvestor cannot redeem
        juniorInvestor.doRedeem(jSupplyAmount);
    }
}