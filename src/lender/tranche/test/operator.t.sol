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

import "ds-test/test.sol";

import "../../test/mock/tranche.sol";
import "../../test/mock/assessor.sol";
import "../../test/mock/distributor.sol";
import "../operator/base.sol";
import "../operator/allowance.sol";
import "../operator/whitelist.sol";

contract WhitelistOperatorLike {
    function supply(uint currencyAmount) public;
    function redeem(uint tokenAmount) public;
}

contract Investor {

    function doSupply(address operator, uint amount) public {
        WhitelistOperatorLike(operator).supply(amount);
    }

    function doRedeem(address operator, uint amount) public {
        WhitelistOperatorLike(operator).redeem(amount);
    }

}

contract OperatorTest is DSTest {

    uint256 constant ONE = 10 ** 27;

    AssessorMock assessor;
    TrancheMock tranche;
    DistributorMock distributor;
    WhitelistOperator whitelist;
    AllowanceOperator allowance;
    Investor investor;


    function setUp() public {
        assessor =  new AssessorMock();
        assessor.setReturn("tokenPrice", ONE);
        assessor.setReturn("supplyApprove", true);
        assessor.setReturn("redeemApprove", true);

        tranche = new TrancheMock();
        investor = new Investor();
        distributor = new DistributorMock();
        whitelist = new WhitelistOperator(address(tranche), address(assessor), address(distributor));
        allowance = new AllowanceOperator(address(tranche), address(assessor), address(distributor));
        whitelist.depend("tranche", address(tranche));
        allowance.depend("tranche", address(tranche));
    }

    function testWhitelistSupplyAdmin() public {
        whitelist.relyInvestor(address(this));
        whitelist.supply(100 ether);
        assertEq(tranche.calls("supply"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
    }

    function testFailWhitelistSupplyAdmin() public {
        whitelist.relyInvestor(address(this));
        assessor.setReturn("supplyApprove", false);
        whitelist.supply(100 ether);
    }

    function testWhitelistRedeemAdmin() public {
        whitelist.relyInvestor(address(this));
        whitelist.redeem(100 ether);
        assertEq(tranche.calls("redeem"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
        assertEq(distributor.calls("balance"), 1);
    }

    function testFailWhitelistRedeemAdmin() public {
        whitelist.relyInvestor(address(this));
        assessor.setReturn("redeemApprove", false);
        whitelist.redeem(100 ether);
    }

    function testWhitelistSupplyInvestor() public {
        whitelist.relyInvestor(address(investor));
        investor.doSupply(address(whitelist), 100 ether);
        assertEq(tranche.calls("supply"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
        assertEq(tranche.values_uint("supply_currencyAmount"), 100 ether);
        assertEq(tranche.values_uint("supply_tokenAmount"), 100 ether);
        assertEq(distributor.calls("balance"), 1);
    }

    function testWhitelistRedeemInvestor() public {
        whitelist.relyInvestor(address(investor));
        investor.doRedeem(address(whitelist), 100 ether);
        assertEq(tranche.calls("redeem"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
        assertEq(tranche.values_uint("redeem_currencyAmount"), 100 ether);
        assertEq(tranche.values_uint("redeem_tokenAmount"), 100 ether);
        assertEq(distributor.calls("balance"), 1);
    }

    function testFailWhitelistSupply() public {
        whitelist.supply(100 ether);
    }

    function testFailWhitelistSupplyInvestor() public {
        investor.doSupply(address(investor), 100 ether);
    }

    function testFailWhitelistRedeem() public {
        whitelist.redeem(100 ether);
    }

    function testFailWhitelistRedeemInvestor() public {
        investor.doRedeem(address(whitelist), 100 ether);
    }

    function testAllowanceSupply() public {
        allowance.approve(address(investor), 100 ether, 100 ether);
        investor.doSupply(address(allowance), 100 ether);
        assertEq(tranche.calls("supply"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
        assertEq(tranche.values_uint("supply_currencyAmount"), 100 ether);
        assertEq(tranche.values_uint("supply_tokenAmount"), 100 ether);
        assertEq(distributor.calls("balance"), 1);
    }

    function testFailAllowanceSupplyNotApproved() public {
        allowance.approve(address(investor), 100 ether, 100 ether);
        assessor.setReturn("supplyApprove", false);
        investor.doSupply(address(allowance), 100 ether);
    }

    function testAllowanceRedeem() public {
        allowance.approve(address(investor), 100 ether, 100 ether);
        investor.doRedeem(address(allowance), 100 ether);
        assertEq(tranche.calls("redeem"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
        assertEq(tranche.values_uint("redeem_currencyAmount"), 100 ether);
        assertEq(tranche.values_uint("redeem_tokenAmount"), 100 ether);
        assertEq(distributor.calls("balance"), 1);
    }

    function testFailAllowanceRedeemNotApproved() public {
        allowance.approve(address(investor), 100 ether, 100 ether);
        assessor.setReturn("redeemApprove", false);
        investor.doRedeem(address(allowance), 100 ether);
    }

    function testFailAllowanceSupply() public {
        allowance.approve(address(investor), 50 ether, 100 ether);
        investor.doSupply(address(allowance), 100 ether);
    }

    function testFailAllowanceRedeem() public {
        assessor.setReturn("tokenPrice", 1 ether);
        allowance.approve(address(investor), 100 ether, 50 ether);
        investor.doRedeem(address(allowance), 100 ether);
    }
}
