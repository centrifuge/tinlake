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

contract SupplyTwoTrancheTest is BaseSystemTest {

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

    function testSimpleSupply() public {
        uint investorBalance = 100 ether;
        currency.mint(juniorInvestor_, investorBalance);
        currency.mint(seniorInvestor_, investorBalance);

        uint jSupplyAmount = 80 ether;
        uint sSupplyAmount = 20 ether;

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        assertEq(currency.balanceOf(address(junior)), jSupplyAmount);
        assertEq(juniorToken.balanceOf(juniorInvestor_), jSupplyAmount);
        assertEq(currency.balanceOf(address(senior)), sSupplyAmount);
        assertEq(seniorToken.balanceOf(seniorInvestor_), sSupplyAmount);

        uint minJuniorRatio = 8 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        // doesn't break ratio, junior supply now 90 and senior supply 20
        uint jAdditionalSupply = 10 ether;
        juniorInvestor.doSupply(jAdditionalSupply);

        assertEq(currency.balanceOf(address(junior)), jSupplyAmount + jAdditionalSupply);
        assertEq(juniorToken.balanceOf(juniorInvestor_), jSupplyAmount + jAdditionalSupply);

        // new loan, should take all from junior and 10 from senior
        uint ceiling = 100 ether;
        createLoanAndWithdraw(borrower_, ceiling);

        assertEq(currency.balanceOf(address(junior)), 0);
        assertEq(currency.balanceOf(address(senior)), 10 ether);
        assertEq(senior.debt(), 10 ether);

        hevm.warp(now + 1 days);

        assertEq(senior.debt(), 10.5 ether);

        // change the ratio, senior can still supply
        FileLike(assessor).file("minJuniorRatio" , 0);
        seniorInvestor.doSupply(sSupplyAmount);
    }

    function testFailSimpleSupply() public {
        uint investorBalance = 100 ether;
        currency.mint(juniorInvestor_, investorBalance);
        currency.mint(seniorInvestor_, investorBalance);

        uint jSupplyAmount = 80 ether;
        uint sSupplyAmount = 20 ether;

        juniorInvestor.doSupply(jSupplyAmount);
        seniorInvestor.doSupply(sSupplyAmount);

        assertEq(currency.balanceOf(address(junior)), jSupplyAmount);
        assertEq(juniorToken.balanceOf(juniorInvestor_), jSupplyAmount);
        assertEq(currency.balanceOf(address(senior)), sSupplyAmount);
        assertEq(seniorToken.balanceOf(seniorInvestor_), sSupplyAmount);

        uint minJuniorRatio = 8 * 10**26;
        FileLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        // doesn't break ratio, junior supply now 90 and senior supply 20
        uint jAdditionalSupply = 10 ether;
        juniorInvestor.doSupply(jAdditionalSupply);

        assertEq(currency.balanceOf(address(junior)), jSupplyAmount + jAdditionalSupply);
        assertEq(juniorToken.balanceOf(juniorInvestor_), jSupplyAmount + jAdditionalSupply);

        // new loan, should take all from junior and 10 from senior
        uint ceiling = 100 ether;
        createLoanAndWithdraw(borrower_, ceiling);

        assertEq(currency.balanceOf(address(junior)), 0);
        assertEq(currency.balanceOf(address(senior)), 10 ether);
        assertEq(senior.debt(), 10 ether);

        hevm.warp(now + 1 days);

        // break ratio, senior cannot supply
        seniorInvestor.doSupply(sSupplyAmount);
    }
}
