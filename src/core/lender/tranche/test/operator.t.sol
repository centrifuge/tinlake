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
import "../operator.sol";

contract OperatorTest is DSTest {

    AssessorMock assessor;
    TrancheMock tranche;
    Operator operator;

    function setUp() public {
        assessor =  new AssessorMock();
        tranche = new TrancheMock();
        operator = new Operator(address(tranche), address(assessor));
        operator.depend("tranche", address(tranche));
    }

    function testSupply() public {
        assessor.setReturn("tokenPrice", 1);
        operator.supply(100);
        assertEq(tranche.calls("supply"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
    }

    function testRedeem() public {
        assessor.setReturn("tokenPrice", 1);
        operator.redeem(100);
        assertEq(tranche.calls("redeem"), 1);
        assertEq(assessor.calls("tokenPrice"), 1);
    }
}