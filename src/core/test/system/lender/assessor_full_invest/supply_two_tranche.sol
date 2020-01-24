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

import "../../system.t.sol";

contract RedeemTwoTrancheTest is BaseSystemTest {

    WhitelistOperator jOperator;
    WhitelistOperator sOperator;

    DefaultDistributor dDistributor;

    Hevm hevm;

    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bytes32 assessor_ = "full_investment";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_,assessor_, deploySeniorTranche);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        createTestUsers();
        createSeniorInvestor();

        jOperator = WhitelistOperator(address(juniorOperator));
        sOperator = WhitelistOperator(address(seniorOperator));
        dDistributor = DefaultDistributor(address(distributor));

    }

    function supplySenior(uint amount) public {
        currency.mint(seniorInvestor_, amount);
        seniorInvestor.doSupply(amount);
        assertEq(currency.balanceOf(address(lenderDeployer.senior())), amount);

        assertEq(seniorERC20.balanceOf(seniorInvestor_), amount);
        assertEq(lenderDeployer.senior().debt(), 0);
    }

    function supplyJunior(uint amount) public {
        currency.mint(juniorInvestor_, amount);

        juniorInvestor.doSupply(amount);
        // currency in tranche
        assertEq(currency.balanceOf(address(lenderDeployer.junior())), amount);
        // junior investor has token
        assertEq(juniorERC20.balanceOf(juniorInvestor_), amount);
    }

    function testFIAssessor_SimpleSupply() public {
        uint seniorInvestorAmount = 100 ether;
        uint juniorInvestorAmount = 200 ether;

        supplySenior(seniorInvestorAmount);
        supplyJunior(juniorInvestorAmount);


        hevm.warp(now + 1 days);

        assertEq(lenderDeployer.senior().debt(), 5 ether);
    }

    function testInterestSenior() public {
        uint amount = 100 ether;
        supplySenior(amount);

        assertEq(lenderDeployer.senior().debt(), 0 ether);
        hevm.warp(now + 1 days);
        assertEq(lenderDeployer.senior().debt(), 5 ether);
        hevm.warp(now + 1 days);
        assertEq(lenderDeployer.senior().debt(), 10.25 ether);
    }
}