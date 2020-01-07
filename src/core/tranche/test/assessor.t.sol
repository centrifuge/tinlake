// Copyright (C) 2019  Centrifuge

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

import "../assessor.sol";
import "../../test/mock/trancheManager.sol";
import "../../test/mock/operator.sol";

contract AssessorTest is DSTest {

    Assessor assessor;
    TrancheManagerMock trancheManager;
    OperatorMock seniorOperator = new OperatorMock();
    OperatorMock juniorOperator = new OperatorMock();

    function setUp() public {
        trancheManager = new TrancheManagerMock();
        assessor = new Assessor(address(trancheManager));
        trancheManager.addTranche("senior", 70, address(seniorOperator));
        trancheManager.addTranche("junior", 30, address(juniorOperator));
    }

    function getAssetValueFor(address operator, uint seniorTrancheDebt, uint seniorTrancheReserve, uint juniorTrancheDebt, uint juniorTrancheReserve, uint poolValue) internal returns (uint) { 
        trancheManager.setPoolValueReturn(poolValue);

        seniorOperator.setBalance(seniorTrancheReserve);
        seniorOperator.setDebtOf(seniorTrancheDebt);

        juniorOperator.setBalance(juniorTrancheReserve);
        juniorOperator.setDebtOf(juniorTrancheDebt);

        return assessor.getAssetValueFor(address(operator));
    }

    function testSeniorAssetValueHealthyPool() public {
        uint seniorTrancheDebt = 200;
        uint seniorTrancheReserve = 150;
        // default 0 - junior tranche does not need to keep track of debt value 
        uint juniorTrancheDebt = 0;
        uint juniorTrancheReserve = 50;  
        uint poolValue = 250; 

        trancheManager.setIsJuniorReturn(false); 
        
        uint assetValue = getAssetValueFor(address(seniorOperator), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 350);
    }

    function testSeniorAssetValueWithLosses() public { 
        uint seniorTrancheDebt = 200;
        uint seniorTrancheReserve = 150;
        uint juniorTrancheDebt = 0;
        uint juniorTrancheReserve = 50;  
        uint poolValue = 100; 

        trancheManager.setIsJuniorReturn(false); 
        
        uint assetValue = getAssetValueFor(address(seniorOperator), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 300);
    }

    function testJuniorAssetValueHealthyPool() public { 
        uint seniorTrancheDebt = 200;
        uint seniorTrancheReserve = 150;
        uint juniorTrancheDebt = 0;
        uint juniorTrancheReserve = 50;  
        uint poolValue = 800; 

        trancheManager.setIsJuniorReturn(true); 
        
        uint assetValue = getAssetValueFor(address(juniorOperator), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 650);
    }

    function testJuniorAssetValueWithLosses() public { 
        uint seniorTrancheDebt = 500;
        uint seniorTrancheReserve = 150; 
        uint juniorTrancheDebt = 0;
        uint juniorTrancheReserve = 200;  
        uint poolValue = 200;  

        trancheManager.setIsJuniorReturn(true); 

        uint assetValue = getAssetValueFor(address(juniorOperator), seniorTrancheDebt, seniorTrancheReserve, juniorTrancheDebt, juniorTrancheReserve, poolValue);
        assertEq(assetValue, 0);
    }
}