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

import "../senior_tranche.sol";
import "../../../test/simple/token.sol";

contract Hevm {
    function warp(uint256) public;
}

contract SeniorTrancheTest is DSTest, DSMath {
    SeniorTranche senior;
    address senior_;
    SimpleToken token;
    SimpleToken currency;

    Hevm hevm;

    address self;

    function setUp() public {
        // Simple ERC20
        token = new SimpleToken("TIN", "Tranche", "1", 0);
        currency = new SimpleToken("CUR", "Currency", "1", 0);

        senior = new SeniorTranche(address(token), address(currency));
        senior_ = address(senior);
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        self = address(this);
    }

    function testFileRate() public {
        uint ratePerSecond = 1000000593415115246806684338; // 5% per day
        senior.file("rate", ratePerSecond);
        assertEq(senior.ratePerSecond(), ratePerSecond);
    }

    function borrow(uint amount) public {
        senior.borrow(self, amount);
        assertEq(currency.balanceOf(self), amount);
        assertEq(currency.balanceOf(senior_), 0);
        assertEq(senior.debt(), amount);
    }

    function testSeniorBorrow() public {
        uint ratePerSecond = 1000000564701133626865910626; // 5% per day
        senior.file("rate", ratePerSecond);

        uint amount = 100 ether;
        currency.mint(address(senior), amount);
        borrow(amount);
    }

    function testSeniorDebtIncrease() public {
        uint ratePerSecond = 1000000564701133626865910626; // 5% per day
        senior.file("rate", ratePerSecond);

        uint amount = 100 ether;
        currency.mint(address(senior), amount);
        borrow(amount);

        hevm.warp(now + 1 days);
        assertEq(senior.debt(), 105 ether);
        hevm.warp(now + 1 days);
        assertEq(senior.debt(), 110.25 ether);
    }

    function testSeniorRepay() public {
        uint ratePerSecond = 1000000564701133626865910626; // 5% per day
        senior.file("rate", ratePerSecond);

        uint amount = 100 ether;
        currency.mint(address(senior), amount);
        borrow(amount);

        hevm.warp(now + 2 days);
        uint expectedDebt = 110.25 ether; // 100 * 1.05^2
        uint interest = expectedDebt-amount;
        currency.mint(self, interest); // extra to repay interest

        currency.approve(senior_, uint(-1));

        senior.repay(self, interest);
        assertEq(senior.debt(), expectedDebt-interest);
        assertEq(currency.balanceOf(senior_), interest);

        // increase again
        uint debt = senior.debt();
        assertEq(debt, amount); // previous interest has been repaid
        hevm.warp(now + 1 days);
        assertEq(senior.debt(), 105 ether); // 100 * 1.05

        currency.mint(self, 5 ether); // extra to repay interest
        senior.repay(self, 105 ether); // repay rest

        assertEq(currency.balanceOf(senior_), expectedDebt+ 5 ether);
        assertEq(senior.debt(), 0);

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
