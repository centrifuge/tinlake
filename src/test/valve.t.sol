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

import "../valve.sol";

contract TokenMock {
    uint public totalSupply;
    uint public mint_calls;
    uint public burn_calls;
    uint public wad;
    mapping (address => uint) public balanceOf; 

    constructor () public {}

    function setTotalSupply(uint totalSupply_) public {
        totalSupply = totalSupply_;
    }
    function setBalanceOf(address usr, uint wad_) public {
        balanceOf[usr] = wad_;
    }

    function reset() public {
        mint_calls = 0;
        burn_calls = 0;
        wad = 0;
    }

    function mint(address usr, uint wad_) public {
        mint_calls += 1;
        wad = wad_;
    }
    function burn(address usr, uint wad_) public {
        burn_calls += 1;
        wad = wad_;
    }
}

contract ShelfMock {
    uint public bags;
    uint public calls;

    constructor () public {
        bags = 0;
        calls = 0;
    }
    
    function setCalls(uint calls_) public {
        calls = calls_;
    }

    function setBags(uint bags_) public {
        bags = bags_;
    }
}

contract ValveTest is DSTest {
    address self;
    TokenMock tkn;
    ShelfMock shelf;
    Valve valve;

    function setUp() public {
        self = address(this);
        tkn = new TokenMock();
        shelf = new ShelfMock();
        valve = new Valve(address(tkn), address(shelf));
    }
    
    function testMint() public {
        tkn.setTotalSupply(50);
        shelf.setBags(150);
        valve.mint(self, 100);
        assertEq(tkn.mint_calls(), 1);
        tkn.reset();
    }

    function testBurn() public {
        tkn.setTotalSupply(100);
        tkn.setBalanceOf(self, 50);
        shelf.setBags(50);
        valve.burnMax(self);
        assertEq(tkn.burn_calls(), 1);
        assertEq(tkn.wad(), 50);
        tkn.reset();
    }

    function testFailMint() public {
        valve.mint(self, 50); 
    }

    function testBurnZero() public {
        valve.burnMax(self);
        assertEq(tkn.wad(), 0);
        tkn.reset();
        tkn.reset();
    }

    function testBurnBelowPeg() public {
        tkn.setTotalSupply(50);
        shelf.setBags(50);
        valve.burnMax(self);
        assertEq(tkn.wad(), 0);
    }

    function testBalance() public {
        tkn.setTotalSupply(50);
        shelf.setBags(40);
        tkn.setBalanceOf(self, 10);
        valve.balance(self);
        assertEq(tkn.burn_calls(), 1);
        assertEq(tkn.wad(), 10);
        tkn.reset();

        tkn.setBalanceOf(self, 5);
        valve.balance(self);
        assertEq(tkn.burn_calls(), 1);
        assertEq(tkn.wad(), 5);
        tkn.reset();
        tkn.setBalanceOf(self, 0);
        
        tkn.setTotalSupply(32);
        valve.balance(self);
        assertEq(tkn.mint_calls(), 1);
        assertEq(tkn.wad(), 8);
        tkn.reset();
    }
}
