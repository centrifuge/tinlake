// Copyright (C) 2019 Centrifuge

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

import "../trancheManager.sol";
import "../../test/mock/pile.sol";
import "../../test/mock/operator.sol";

contract TrancheManagerTest is DSTest {

    PileMock pile;
    TrancheManager trancheManager;
    OperatorMock seniorOperator = new OperatorMock();
    OperatorMock juniorOperator = new OperatorMock();

    function setUp() public {
        pile = new PileMock();
        trancheManager = new TrancheManager(address(pile));
        //add tranches
        trancheManager.addTranche("senior", 70, address(seniorOperator));
        trancheManager.addTranche("junior", 30, address(juniorOperator));
    }

    function testIsJunior() public { 
        bool isJunior = trancheManager.isJunior(address(juniorOperator));
        assert(isJunior);
    }

    function testIsNotJunior() public { 
        bool isJunior = trancheManager.isJunior(address(seniorOperator));
        assert(!isJunior);
    }

    function testGetSeniorOperator() public {
        address operatorAddress = trancheManager.seniorOperator();
        assertEq(operatorAddress, address(seniorOperator));  
    }

    function testGetjuniorOperator() public {
        address operatorAddress = trancheManager.juniorOperator();
        assertEq(operatorAddress, address(juniorOperator));  
    }
}


