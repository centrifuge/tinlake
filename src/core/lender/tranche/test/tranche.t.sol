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
import "ds-math/math.sol";

import "../tranche.sol";
import "../../../test/simple/token.sol";

contract Hevm {
    function warp(uint256) public;
}

contract TrancheTest is DSTest, DSMath {
    Tranche tranche;
    address tranche_;
    SimpleToken token;
    SimpleToken currency;

    Hevm hevm;

    address self;

    function setUp() public {
        // Simple ERC20
        token = new SimpleToken("TIN", "Tranche", "1", 0);
        currency = new SimpleToken("CUR", "Currency", "1", 0);
        tranche = new Tranche(address(token), address(currency));
        tranche_ = address(tranche);
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        self = address(this);
    }

    function testBalance() public {
        currency.mint(tranche_, 100);
        currency.mint(self, 100);
        uint b = tranche.balance();
        assertEq(b, 100);
    }
    function testTokenSupply() public {
        token.mint(tranche_, 100);
        uint s = tranche.tokenSupply();
        assertEq(s, 100);
    }

    function testSupply() public {
        currency.mint(self, 100);
        currency.approve(tranche_, uint(-1));
        tranche.supply(self, 50, 25);
        assertEq(currency.balanceOf(tranche_), 50);
        assertEq(currency.balanceOf(self), 50);
        assertEq(tranche.tokenSupply(), 25);
    }
    function testRedeem() public {
        currency.mint(tranche_, 100);
        currency.approve(tranche_, uint(-1));
        token.approve(tranche_, uint(-1));
        token.mint(self, 50);
        tranche.redeem(self, 100, 50);
        assertEq(currency.balanceOf(self), 100);
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
        currency.approve(tranche_, uint(-1));
        assertEq(currency.balanceOf(tranche_), 100);
        tranche.borrow(self, 100);
        assertEq(currency.balanceOf(tranche_), 0);
        assertEq(currency.balanceOf(self), 100);
    }


    //    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }

}
