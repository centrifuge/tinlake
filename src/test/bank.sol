// Copyright (C) 2019 lucasvo

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

import "../ceiling.sol";

contract MockMint {
    uint public count;
    uint public totalSupply;

    address[] public guys;
    uint[] public    wads;

    function setSupply(uint sup) public {
        totalSupply = sup;
    }
    
    function mint(address guy, uint wad) public {
        guys.push(guy);
        wads.push(wad);
        count = count+1;
    }
}

contract CeilingTest is DSTest  {
    Ceiling roof;
    MockMint minter;
    address self;

    function setUp() public {
        minter = new MockMint();
        self = address(this);
    }

    function createRoof (uint max) 
        internal 
        returns (Ceiling) 
    {
        return new Ceiling(address(minter), max);
    }

    function testMint() public logs_gas {
        roof = createRoof(10);
        uint prev = minter.count();
        assertEq(prev, 0);
        minter.setSupply(0);
        roof.mint(self, 10);
        assertEq(minter.count(), 1);
        assertEq(minter.guys(0), self);
        assertEq(minter.wads(0), 10);
    }

    function testFailMint() public {
        roof = createRoof(10);
        minter.setSupply(10);
        roof.mint(self, 10);
    }
}
