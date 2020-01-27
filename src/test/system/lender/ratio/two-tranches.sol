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

contract AssessorLike {
    function file(bytes32, uint) public;
    function currentJuniorRatio() public returns(uint);
    function supplyApprove(address tranche, uint amount) public returns (bool);
    function redeemApprove(address tranche, uint amount) public returns (bool);
}

contract RatioTests is BaseSystemTest {
    Hevm hevm;

    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bytes32 assessor_ = "default";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_,assessor_, deploySeniorTranche);
        createTestUsers(deploySeniorTranche);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
    }

    function testSupplyJuniorFirst() public {
        uint seniorInvestorAmount = 400 ether;
        uint juniorInvestorAmount = 100 ether;

        // minJuniorRatio 20%
        uint minJuniorRatio = 2 * 10**26;
        AssessorLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        supplyJunior(juniorInvestorAmount);
        supplySenior(seniorInvestorAmount);

        // currency equals token amount
        seniorInvestor.doRedeem(seniorInvestorAmount);
        juniorInvestor.doRedeem(juniorInvestorAmount);
    }

    function testFailNotSupplyJuniorFirst() public {
        uint seniorInvestorAmount = 400 ether;

        // minJuniorRatio 20%
        uint minJuniorRatio = 2 * 10**26;
        AssessorLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        supplySenior(seniorInvestorAmount);
    }

    function testFailSupplyNotApproved() public {
        uint seniorInvestorAmount = 401 ether;
        uint juniorInvestorAmount = 100 ether;

        // minJuniorRatio 20%
        uint minJuniorRatio = 2 * 10**26;
        AssessorLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        supplyJunior(juniorInvestorAmount);
        // senior supply not approved
        supplySenior(seniorInvestorAmount);
    }

    function testAdditionalSupply() public {
        uint seniorInvestorAmount = 400 ether;
        uint juniorInvestorAmount = 100 ether;

        // minJuniorRatio 20%
        uint minJuniorRatio = 2 * 10**26;
        AssessorLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        supplyJunior(juniorInvestorAmount);
        supplySenior(seniorInvestorAmount);

        // additional junior supply
        supplyJunior(50 ether);

        // junior 150 ether max senior: 400 ether
        supplySenior(200 ether);

        assertEq(AssessorLike(assessor).currentJuniorRatio(), minJuniorRatio);
    }

    function testJuniorRedeemFirst() public {
        uint seniorInvestorAmount = 400 ether;
        uint juniorInvestorAmount = 200 ether;

        // minJuniorRatio 20%
        uint minJuniorRatio = 2 * 10**26;
        AssessorLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        supplyJunior(juniorInvestorAmount);
        supplySenior(seniorInvestorAmount);

        juniorInvestor.doRedeem(100 ether);

        assertEq(AssessorLike(assessor).currentJuniorRatio(), minJuniorRatio);
    }

    function testBreakRatioWithDefault() public {
        uint seniorInvestorAmount = 400 ether;
        uint juniorInvestorAmount = 100 ether;

        // minJuniorRatio 20%
        uint minJuniorRatio = 2 * 10**26;
        AssessorLike(assessor).file("minJuniorRatio" , minJuniorRatio);

        supplyJunior(juniorInvestorAmount);
        supplySenior(seniorInvestorAmount);

        (uint loan,) = createLoanAndWithdraw(borrower_, 100 ether);

        // loan B has defaulted
        uint threshold = 90 ether;
        uint recoveryPrice = 90 ether;
        addKeeperAndCollect(loan, threshold, borrower_, recoveryPrice);

       assertTrue(AssessorLike(assessor).currentJuniorRatio() < minJuniorRatio);

        // no additional senior investment allowed
        assertTrue(AssessorLike(assessor).supplyApprove(address(senior), 1) == false);

        // additional investment restores ratio
        supplyJunior(10 ether);
        assertTrue(AssessorLike(assessor).currentJuniorRatio() == minJuniorRatio);

        // more junior investment
        supplyJunior(10 ether);

        // allows additional investment from senior
        assertTrue(AssessorLike(assessor).supplyApprove(address(senior), 40 ether) == true);
    }
}
