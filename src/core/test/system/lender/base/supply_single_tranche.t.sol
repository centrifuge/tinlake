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

contract SupplyTest is SystemTest {

    WhitelistOperator operator;
    BaseDistributor base;

    Investor juniorInvestor;
    address  juniorInvestor_;

    function setUp() public {
        bytes32 juniorOperator_ = "whitelist";
        bytes32 distributor_ = "base";
        baseSetup(juniorOperator_, distributor_);
        operator = WhitelistOperator(address(juniorOperator));
        base = BaseDistributor(address(distributor));

        // setup users
        juniorInvestor = new Investor(address(operator), currency_, address(juniorERC20));
        juniorInvestor_ = address(juniorInvestor);

        operator.relyInvestor(juniorInvestor_);
        rootAdmin.relyLenderAdmin(address(this));
    }

    function testSimpleSupply() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        currency.mint(juniorInvestor_, investorBalance);

        juniorInvestor.doSupply(supplyAmount);
        assertPostCondition(supplyAmount);
        assertEq(currency.balanceOf(address(junior)), supplyAmount);
    }

    function assertPostCondition(uint supplyAmount) public {
        // assert: shelf is balanced, excess has either been transferred to tranches or needed money transferred from distributor -> shelf
        assertEq(shelf.balance() - currency.balanceOf(address(shelf)), 0);
        // assert: junior investor token balance == amount supplied (because no other currency was supplied yet)
        assertEq(juniorERC20.balanceOf(juniorInvestor_), supplyAmount);
    }
}