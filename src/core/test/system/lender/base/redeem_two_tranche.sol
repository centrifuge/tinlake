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

contract RedeemTwoTrancheTest is BaseSystemTest {

    WhitelistOperator jOperator;
    WhitelistOperator sOperator;

    DefaultDistributor dDistributor;

    Investor juniorInvestor;
    address  juniorInvestor_;

    Investor seniorInvestor;
    address  seniorInvestor_;

    function setUp() public {
        bytes32 operator_ = "whitelist";
        bytes32 distributor_ = "default";
        bool deploySeniorTranche = true;
        baseSetup(operator_, distributor_, deploySeniorTranche);

        jOperator = WhitelistOperator(address(juniorOperator));
        sOperator = WhitelistOperator(address(seniorOperator));
        dDistributor = DefaultDistributor(address(distributor));

        // setup users
        juniorInvestor = new Investor(address(jOperator), currency_, address(juniorERC20));
        juniorInvestor_ = address(juniorInvestor);

        // setup users
        seniorInvestor = new Investor(address(jOperator), currency_, address(seniorERC20));
        seniorInvestor_ = address(seniorInvestor);

        jOperator.relyInvestor(juniorInvestor_);
        sOperator.relyInvestor(seniorInvestor_);
    }

    function supply(uint balance, uint amount) public {
        currency.mint(juniorInvestor_, balance);
        juniorInvestor.doSupply(amount);
    }

    function testSimpleRedeem() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        uint redeemAmount = supplyAmount;
        supply(investorBalance, supplyAmount);
        juniorInvestor.doRedeem(redeemAmount);
    }
}