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

pragma solidity >=0.4.23;

import "ds-test/test.sol";

import "../../test/mock/tranche.sol";
import "../../test/mock/assessor.sol";
import "../operator/base.sol";
import "../operator/allowance.sol";
import "../operator/whitelist.sol";

contract OperatorTest is DSTest {

    AssessorMock assessor;
    TrancheMock tranche;
    WhitelistOperator whitelist;
    AllowanceOperator allowance;


    function setUp() public {
        assessor =  new AssessorMock();
        tranche = new TrancheMock();
        whitelist = new WhitelistOperator(address(tranche), address(assessor));
        allowance = new AllowanceOperator(address(tranche), address(assessor));
        whitelist.depend("tranche", address(tranche));
        allowance.depend("tranche", address(tranche));
    }

    function testWhitelistSupply() public {
        assessor.setReturn("tokenPrice", 1 ether);
        whitelist.relyInvestor(address(this));
        whitelist.supply(100 ether);
        assertEq(tranche.calls("supply"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
    }

    function testWhitelistRedeem() public {
        assessor.setReturn("tokenPrice", 1 ether);
        whitelist.relyInvestor(address(this));
        whitelist.redeem(100 ether);
        assertEq(tranche.calls("redeem"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
    }

    function testFailWhitelistSupply() public {
        assessor.setReturn("tokenPrice", 1 ether);
        whitelist.supply(100 ether);
    }

    function testFailWhitelistRedeem() public {
        assessor.setReturn("tokenPrice", 1 ether);
        whitelist.redeem(100 ether);
    }

    function testAllowanceSupply() public {
        assessor.setReturn("tokenPrice", 1 ether);
        allowance.approve(address(this), 100 ether, 100 ether);
        allowance.supply(100 ether);
        assertEq(tranche.calls("supply"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
    }

    function testAllowanceRedeem() public {
        assessor.setReturn("tokenPrice", 1 ether);
        allowance.approve(address(this), 100 ether, 100 ether);
        allowance.redeem(100 ether);
        assertEq(tranche.calls("redeem"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
    }

    function testFailAllowanceSupply() public {
        assessor.setReturn("tokenPrice", 1 ether);
        allowance.approve(address(this), 100 ether, 50 ether);
        allowance.supply(100 ether);
    }

    function testFailAllowanceRedeem() public {
        assessor.setReturn("tokenPrice", 1 ether);
        allowance.approve(address(this), 50 ether, 100 ether);
        allowance.redeem(100 ether);
    }
}