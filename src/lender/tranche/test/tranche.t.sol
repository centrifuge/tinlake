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

pragma solidity >=0.5.15 <0.6.0;

import "ds-test/test.sol";

import "../tranche.sol";
import "../../../test/simple/token.sol";

contract Hevm {
    function warp(uint256) public;
}

contract TrancheTest is DSTest {
    Tranche tranche;
    address tranche_;
    SimpleToken token;
    SimpleToken currency;

    address self;

    function setUp() public {
        // Simple ERC20
        token = new SimpleToken("TIN", "Tranche", "1", 0);
        currency = new SimpleToken("CUR", "Currency", "1", 0);
        tranche = new Tranche(address(token), address(currency));
        tranche_ = address(tranche);

        self = address(this);
    }

    function testBalance() public {
        currency.mint(tranche_, 100 ether);
        currency.mint(self, 100 ether);
        uint b = tranche.balance();
        assertEq(b, 100 ether);
    }

    function testTokenSupply() public {
        token.mint(tranche_, 100 ether);
        uint s = tranche.tokenSupply();
        assertEq(s, 100 ether);
    }

    function testSupply() public {
        currency.mint(self, 100 ether);
        currency.approve(tranche_, uint(-1));
        tranche.supply(self, 50 ether, 25 ether);
        assertEq(currency.balanceOf(tranche_), 50 ether);
        assertEq(currency.balanceOf(self), 50 ether);
        assertEq(tranche.tokenSupply(), 25 ether);
    }

    function testRedeem() public {
        currency.mint(tranche_, 100 ether);
        currency.approve(tranche_, uint(-1));
        token.approve(tranche_, uint(-1));
        token.mint(self, 50 ether);
        tranche.redeem(self, 100 ether, 50 ether);
        assertEq(currency.balanceOf(self), 100 ether);
        assertEq(token.balanceOf(self), 0);
    }

    function testRepay() public {
        currency.mint(self, 100);
        currency.approve(tranche_, uint(-1));
        tranche.repay(self, 100);
        assertEq(currency.balanceOf(tranche_), 100);
        assertEq(currency.balanceOf(self), 0);
    }

    function testBorrow() public {
        currency.mint(tranche_, 100);
        assertEq(currency.balanceOf(tranche_), 100);
        tranche.borrow(self, 100);
        assertEq(currency.balanceOf(tranche_), 0);
        assertEq(currency.balanceOf(self), 100);
    }
}
