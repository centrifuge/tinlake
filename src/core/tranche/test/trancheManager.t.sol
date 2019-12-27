// Copyright (C) 2019 

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
    OperatorMock equityOperator = new OperatorMock();

    function setUp() public {
        pile = new PileMock();
        trancheManager = new TrancheManager(address(pile));
        //add tranches
        trancheManager.addTranche(70, address(seniorOperator));
        trancheManager.addTranche(30, address(equityOperator));
    }

    function testIsEquity() public { 
        bool isEquity = trancheManager.isEquity(address(equityOperator));
        assert(isEquity);
    }

    function testIsNotEquity() public { 
        bool isEquity = trancheManager.isEquity(address(seniorOperator));
        assert(!isEquity);
    }

    function testIndexOf() public {
        int index = trancheManager.indexOf(address(seniorOperator));
        assertEq(index, 0);  
    }

    function testIndexDoesNotExist() public {
        OperatorMock randomOperator = new OperatorMock();
        int index = trancheManager.indexOf(address(randomOperator));
        assertEq(index, -1);    
    }
}


