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
import "../debt_register.sol";

contract Hevm {
    function warp(uint256) public;
}

contract DebtRegisterTest is DSTest {
    DebtRegister debtRegister;
    Hevm hevm;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        debtRegister = new DebtRegister();
    }

    function assertDebt(uint loan, uint rate, uint should) public {
        uint debt = debtRegister.debt(loan);
        assertEq(debt, should);
    }

    function testSingleCompoundSec() public  {
        /*
        Compound period in pile is in seconds
        compound seconds = (1+r/n)^nt

        rate = (1+(r/n))*10^27 (27 digits precise)

        Example:
        given a 1.05 interest per day (seconds per day 3600 * 24)

        r = 0.05
        i = (1+r/(3600*24))^(3600*24) would result in i = 1.051271065957324097526787272

        rate = (1+(0.05/(3600*24)))*10^27
        rate = 1000000593415115246806684338
        */
        uint rate = 1000000593415115246806684338; // 5 % per day compound in seconds
        uint loan = 1;
        uint principal = 66 ether;
        debtRegister.file(rate, rate);
        debtRegister.set(loan, rate);
        debtRegister.drip(rate);
        debtRegister.increase(loan, principal);

        // one day later
        hevm.warp(now + 1 days);
        debtRegister.drip(rate);
        uint should = calculateDebt(rate, principal, uint(3600*24));
        assertDebt(loan, rate, should);
    }

    function testSingleCompoundDay() public {
        /*
        Compound period in pile is in seconds
        compound seconds = (1+r/n)^nt

        rate = (1+(r/n))*10^27 (27 digits precise)

        Example: compound in seconds should result in 1.05 interest per day

        given i = 1.05
        solve equation for r
        i = (1+r/n)^nt
        r = n * (i^(1/n)-1

        use calculated r for rate equation
        rate = (1+((n * (i^(1/n)-1)/n))*10^27

        simplified
        rate = i^(1/n) * 10^27

        rate = 1.05^(1/(3600*24)) * 10^27 // round 27 digit
        rate = 1000000564701133626865910626

        */
        uint rate = uint(1000000564701133626865910626); // 5 % day
        uint loan = 1;
        uint principal = 66 ether;

        debtRegister.file(rate, rate);
        debtRegister.set(loan, rate);
        debtRegister.drip(rate);
        debtRegister.increase(loan, principal);
        assertDebt(loan, rate, 66 ether);

        // two days later
        hevm.warp(now + 2 days);
        assertEq(debtRegister.debt(loan), 72.765 ether); // 66 ether * 1,05**2
        debtRegister.drip(rate);
        assertDebt(loan, rate, 72.765 ether);
    }

    function testSingleCompoundYear() public {
        /*
        i = 1.12 // 12%
        n = 24 * 3600 * 365

        simplified rate
        rate = i^(1/n) * 10^27

        rate = 1.12^(1/(3600*24*365)) * 10^27
        rate = 1000000003593629043335673583
        */
        uint rate = uint(1000000003593629043335673583); // 12 % per year
        uint loan = 1;
        uint principal = 66 ether;
        debtRegister.file(rate, rate);
        debtRegister.set(loan, rate);
        debtRegister.drip(rate);
        debtRegister.increase(loan, principal);

        assertDebt(loan, rate, 66 ether);

        // on year later
        hevm.warp(now + 365 days);
        debtRegister.drip(rate);
        assertDebt(loan, rate, 73.92 ether); // 66 ether * 1,12
    }

    function testDrip() public {
        uint rate = uint(1000000564701133626865910626); // 5 % / day
        debtRegister.file(rate, rate);
        (uint debt1, uint rateIndex1, uint ratePerSecond1, uint lastUpdated1 ) = debtRegister.rates(rate);
        assertEq(ratePerSecond1, rate);
        assertEq(lastUpdated1, now);
        assertEq(debt1, 0);

        // on day later
        hevm.warp(now + 1 days);

        (debt1,  rateIndex1,  ratePerSecond1,  lastUpdated1 ) = debtRegister.rates(rate);
        assertEq(ratePerSecond1, rate);
        assertEq(debt1, 0);
        assertTrue(lastUpdated1 != now);

        debtRegister.drip(rate);

        (uint debt2, uint rateIndex2, uint ratePerSecond2, uint lastUpdated2 ) = debtRegister.rates(rate);
        assertEq(ratePerSecond2, rate);
        assertEq(lastUpdated2, now);
        assertEq(debt2, 0);
        assertTrue(rateIndex1 != rateIndex2);
    }

    function testMaxrateIndex() public {
        // rateIndex is uint, max value = (2^256)-1 = 1.1579209e+77
        // rateIndex initial 10^27
        uint rate = uint(1000000564701133626865910626); // 5 % / daily
        debtRegister.file(rate, rate);
        hevm.warp(now + 1050 days); // 1,05 ^1050 = 1.7732257e+22

        // init rateIndex 10^27 *  1.7732257 * 10^22  ~ rateIndex 10^49
        // rdiv operation needs to mul rateIndex with ONE (10^27)
        // therefore: 10^49 * 10^27 = 10^76 < 1.1579209e+77
        debtRegister.drip(rate);
    }

    function testFailrateIndexTooHigh() public {
        // rateIndex is uint, max value = (2^256)-1 = 1.1579209e+77
        // rateIndex initial 10^27
        uint rate = uint(1000000564701133626865910626); // 5 % / daily
        debtRegister.file(rate, rate);
        hevm.warp(now + 1100 days); // 1,05 ^1100 = 2.0334288e+23

        // init rateIndex 10^27 *  2.0334288 * 10^23  ~ rateIndex 10^50
        // rdiv operation needs to mul rateIndex with ONE (10^27)
        // therefore: 10^50 * 10^27 = 10^77 same power as max value 1.1579209e+77
        debtRegister.drip(rate);
    }

    function testMaxDebt() public {
        uint rate = uint(1000000564701133626865910626); // 5 % day
        debtRegister.file(rate, rate);
        uint loan = 1;
        uint principal = 1000000000  ether; // one billion 10^9 * 10^18 = 10^28
        debtRegister.drip(rate);
        debtRegister.set(loan, rate);
        debtRegister.increase(loan, principal);

        // 150 days later
        hevm.warp(now + 1050 days); // produces max ~ rateIndex 10^49
        // debt ~ 10^27 * 10^49 =  10^76 (max uint is 10^77)
        debtRegister.drip(rate);
    }

    function testChange() public {
        uint highRate = uint(1000001311675458706187136988); // 12 % per day
        uint lowRate = uint(1000000564701133626865910626); // 5 % / day

        uint loan = 1;
        uint principal = 100 ether;

        debtRegister.file(highRate, highRate);
        debtRegister.file(lowRate, lowRate);
        debtRegister.drip(highRate);
        debtRegister.drip(lowRate);
        debtRegister.set(loan, lowRate);
        debtRegister.increase(loan, principal);
        assertDebt(loan, lowRate, 100 ether);

        hevm.warp(now + 1 days);
        debtRegister.drip(lowRate);
        debtRegister.drip(highRate);
        assertDebt(loan, lowRate, 105 ether);

        (uint rateTotalDebt, , ,) = debtRegister.rates(lowRate); assertEq(rateTotalDebt, 105 ether);
        (rateTotalDebt, , ,)  = debtRegister.rates(highRate); assertEq(rateTotalDebt, 0);
        assertEq(debtRegister.total(), 105 ether);

        // rate switch
        debtRegister.change(loan, highRate);
        assertDebt(loan, highRate, 105 ether);

        (rateTotalDebt, , ,) = debtRegister.rates(lowRate); assertEq(rateTotalDebt, 0 );
        (rateTotalDebt, , ,)  = debtRegister.rates(highRate); assertEq(rateTotalDebt, 105 ether);
        assertEq(debtRegister.total(), 105 ether);

        hevm.warp(now + 1 days);

        //105 * 1.12 =117.6
        debtRegister.drip(highRate);
        assertDebt(loan, highRate, 117.6 ether);
    }


    function calculateDebt(uint rate, uint principal, uint time) internal pure returns(uint z) {
        z = rmul(principal, rpow(rate, time, ONE));
    }

    function rad(uint wad_) internal pure returns (uint) {
        return wad_ * 10 ** 27;
    }

    function wad(uint rad_) internal pure returns (uint) {
        return rad_ / 10 ** 27;
    }

    // --- Math ---
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

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
}
