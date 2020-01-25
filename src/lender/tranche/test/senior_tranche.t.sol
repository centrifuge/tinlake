// Copyright (C) 2019 Centrifuge

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

import "ds-test/test.sol";
import "tinlake-math/interest.sol";

import "../senior_tranche.sol";
import "../../../test/simple/token.sol";
import "../../test/mock/assessor.sol";

contract Hevm {
    function warp(uint256) public;
}

contract SeniorTrancheTest is DSTest, Interest {
    SeniorTranche senior;
    address senior_;
    SimpleToken token;
    SimpleToken currency;

    AssessorMock assessor;

    Hevm hevm;

    address self;

    function setUp() public {
        // Simple ERC20
        token = new SimpleToken("TIN", "Tranche", "1", 0);
        currency = new SimpleToken("CUR", "Currency", "1", 0);

        assessor = new AssessorMock();

        senior = new SeniorTranche(address(token), address(currency), address(assessor));
        senior_ = address(senior);
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        self = address(this);
        currency.approve(senior_, uint(-1));
    }

    function testFileRate() public {
        uint ratePerSecond = 1000000593415115246806684338; // 5% per day
        senior.file("rate", ratePerSecond);
        assertEq(senior.ratePerSecond(), ratePerSecond);
    }

    function borrow(uint amount) public {
        senior.borrow(self, amount);
        assertEq(currency.balanceOf(self), amount);
        assertEq(currency.balanceOf(senior_), 0);
        assertEq(senior.debt(), amount);
        assertEq(senior.borrowed(), amount);
    }

    function testSeniorBorrow() public {
        uint amount = 100 ether;
        currency.mint(address(senior), amount);
        borrow(amount);
    }

    function testBorrowRepayDebt() public {
        uint ratePerSecond = 1000000564701133626865910626; // 5% per day
        senior.file("rate", ratePerSecond);

        uint amount = 100 ether;
        currency.mint(address(senior), amount);
        borrow(amount);

        assessor.setReturn("accrueTrancheInterest", 5 ether);
        assertEq(senior.debt(), 105 ether);

        assessor.setReturn("accrueTrancheInterest", 5.25 ether);
        assertEq(senior.debt(), 110.25 ether);

        assertEq(senior.borrowed(), 100 ether);
        assertEq(senior.interest(), 10.25 ether);

        // repay
        // stop accrue interest
        assessor.setReturn("accrueTrancheInterest", 0 ether);

        // smaller than interest
        senior.repay(self, 5 ether);
        assertEq(senior.interest(), 5.25 ether);
        assertEq(senior.borrowed(), 100 ether);

        // interest + partial borrowed
        senior.repay(self, 50 ether);
        assertEq(senior.interest(), 0 ether);
        assertEq(senior.borrowed(), 55.25 ether);

        // the rest
        currency.mint(address(this), 10.25 ether);
        senior.repay(self, 55.25 ether);
        assertEq(senior.interest(), 0 ether);
        assertEq(senior.borrowed(), 0 ether);
    }
}
