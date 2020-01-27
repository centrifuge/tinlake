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

contract AllowanceOperatorLike {
function approve(address usr, uint maxCurrency_, uint maxToken_) public;
}

contract AllowanceOperatorTest is BaseSystemTest {

    Hevm hevm;

    function setUp() public {
        bytes32 operator_ = "allowance";
        bytes32 distributor_ = "default";
        bytes32 assessor_ = "default";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_,assessor_, deploySeniorTranche);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

    }

    function testSupplyRedeemWithApprove() public {
        uint juniorInvestorAmount = 100 ether;

        juniorInvestor = new Investor(address(juniorOperator), currency_, address(juniorToken));
        juniorInvestor_ = address(juniorInvestor);

        AllowanceOperatorLike allowanceOperator = AllowanceOperatorLike(address(juniorOperator));
        allowanceOperator.approve(juniorInvestor_, juniorInvestorAmount, juniorInvestorAmount);

        supplyJunior(juniorInvestorAmount);
        // token amount equals currency amount
        juniorInvestor.doRedeem(juniorInvestorAmount);
    }

    function testFailSupplyApprove() public {
        uint juniorInvestorAmount = 100 ether;

        juniorInvestor = new Investor(address(juniorOperator), currency_, address(juniorToken));
        juniorInvestor_ = address(juniorInvestor);

        AllowanceOperatorLike allowanceOperator = AllowanceOperatorLike(address(juniorOperator));
        allowanceOperator.approve(juniorInvestor_, juniorInvestorAmount, juniorInvestorAmount);

        // too much
        supplyJunior(juniorInvestorAmount+1);
    }

    function testFailRedeemApprove() public {
        uint juniorInvestorAmount = 100 ether;

        juniorInvestor = new Investor(address(juniorOperator), currency_, address(juniorToken));
        juniorInvestor_ = address(juniorInvestor);

        AllowanceOperatorLike allowanceOperator = AllowanceOperatorLike(address(juniorOperator));
        allowanceOperator.approve(juniorInvestor_, juniorInvestorAmount, juniorInvestorAmount);

        supplyJunior(juniorInvestorAmount);

        // too much
        juniorInvestor.doRedeem(juniorInvestorAmount+1);
    }

    function testFailSupplyTwice() public {
        uint juniorInvestorAmount = 100 ether;

        juniorInvestor = new Investor(address(juniorOperator), currency_, address(juniorToken));
        juniorInvestor_ = address(juniorInvestor);

        AllowanceOperatorLike allowanceOperator = AllowanceOperatorLike(address(juniorOperator));
        allowanceOperator.approve(juniorInvestor_, juniorInvestorAmount, juniorInvestorAmount);

        supplyJunior(juniorInvestorAmount);

        // should fail
        supplyJunior(juniorInvestorAmount);
    }
}