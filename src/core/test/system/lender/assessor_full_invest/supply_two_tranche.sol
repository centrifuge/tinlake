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

contract RedeemTwoTrancheTest is SystemTest {

    WhitelistOperator jOperator;
    WhitelistOperator sOperator;

    DefaultDistributor dDistributor;



    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bytes32 assessor_ = "full_investment";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_,assessor_, deploySeniorTranche);

        createTestUsers();
        createSeniorInvestor();

        jOperator = WhitelistOperator(address(juniorOperator));
        sOperator = WhitelistOperator(address(seniorOperator));
        dDistributor = DefaultDistributor(address(distributor));


    }

    function testFIAssessor_SimpleSupply() public {
        uint seniorInvestorAmount = 100 ether;
        uint juniorInvestorAmount = 200 ether;

        currency.mint(seniorInvestor_, seniorInvestorAmount);
        currency.mint(juniorInvestor_, juniorInvestorAmount);

        juniorInvestor.doSupply(juniorInvestorAmount);
        // currency in tranche
        assertEq(currency.balanceOf(address(lenderDeployer.junior())), juniorInvestorAmount);
        // junior investor has token
        assertEq(juniorERC20.balanceOf(juniorInvestor_), juniorInvestorAmount);

        seniorInvestor.doSupply(seniorInvestorAmount);
        assertEq(currency.balanceOf(address(lenderDeployer.senior())), seniorInvestorAmount);

        assertEq(seniorERC20.balanceOf(seniorInvestor_), seniorInvestorAmount);
    }
}