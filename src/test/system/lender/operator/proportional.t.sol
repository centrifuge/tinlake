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

import "../../base_system.sol";

contract ProportionalOperatorLike {
    function approve(address usr, uint maxCurrency_) public;
    function file(bytes32 what, bool flag) public;
    function updateReturned(uint currencyReturned, uint principalReturned) public;
    function calcMaxRedeemToken(address usr) public returns (uint);
}

contract ProportionalOperatorTest is BaseSystemTest {
    Hevm hevm;

    ProportionalOperatorLike seniorPropOperator;

    Investor seniorInvestorA;
    address seniorInvestorA_;

    Investor seniorInvestorB;
    address seniorInvestorB_;

    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bytes32 assessor_ = "default";
        bytes32 seniorOperator_ = "proportional";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_, assessor_, deploySeniorTranche, seniorOperator_);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        seniorPropOperator = ProportionalOperatorLike(address(seniorOperator));
        createTestUsers(false);

        seniorInvestorA = new Investor(address(seniorOperator), currency_, address(seniorToken));
        seniorInvestorA_ = address(seniorInvestorA);

    }

    function testSimpleProportionalOperator() public {
        // junior juniorInvestor
        uint juniorAmount = 100 ether;
        supplyJunior(juniorAmount);

        // senior investor
        uint amount = 100 ether;
        seniorPropOperator.approve(seniorInvestorA_, amount);
        currency.mint(seniorInvestorA_, amount);
        seniorInvestorA.doSupply(amount);

        // check supply
        assertEq(seniorToken.balanceOf(seniorInvestorA_), 100 ether);
        assertEq(currency.balanceOf(seniorInvestorA_), 0);

        // stop supply phase in proportional seniorPropOperator
        seniorPropOperator.file("supplyAllowed", false);

        // borrow first loan
        uint principal = 150 ether;
        uint shouldDebt = 157.5 ether; // one day
        uint ratePerSecond = 1000000564701133626865910626; // 5 % a day
        (uint loan, ) = createLoanAndWithdraw(borrower_, principal, ratePerSecond, ratePerSecond);

        hevm.warp(now + 1 days);
        // repay first loan
        repayLoan(borrower_, loan, shouldDebt);

        uint seniorReturn =  52.50 ether; // 50 * 1.05
        uint tokenAmount = 50 ether; // principal
        seniorPropOperator.updateReturned(seniorReturn, tokenAmount);

        assertEq(seniorPropOperator.calcMaxRedeemToken(address(seniorInvestorA)), tokenAmount);
        seniorInvestorA.doRedeem(50 ether);
        assertEq(currency.balanceOf(seniorInvestorA_), seniorReturn);
    }
}
