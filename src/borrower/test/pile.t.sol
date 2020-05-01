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
import "tinlake-math/math.sol";
import "../pile.sol";

contract Hevm {
    function warp(uint256) public;
}

contract PileTest is Interest, DSTest {
    Pile pile;
    Hevm hevm;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        pile = new Pile();
    }

    function _setUpLoan(uint loan, uint rate) internal {
        pile.file("rate", rate, rate);
        pile.setRate(loan, rate);
    }

    function testAccrue() public {
        uint loan = 1;
        uint amount = 66 ether;
        // 12 % per year compound in seconds
        _setUpLoan(loan, 1000000003593629043335673583);
        _increaseDebt(loan, amount);

        hevm.warp(now + 365 days);
        pile.accrue(loan);

        assertDebt(loan, 73.92 ether);
    }

    function _increaseDebt(uint loan, uint amount) internal {
        pile.incDebt(loan, amount);
        assertEq(pile.total(), amount);
        assertEq(pile.debt(loan), amount);
    }

    function _decreaseDebt(uint loan, uint amount) internal {
        uint total = pile.total();
        uint loanDebt = pile.debt(loan);
        pile.decDebt(loan, amount);
        assertEq(pile.total(), safeSub(total, amount));
        assertEq(pile.debt(loan), safeSub(loanDebt, amount));
    }

    function _calculateDebt(uint rate, uint principal, uint time) internal pure returns(uint z) {
        return rmul(principal, rpow(rate, time, ONE));
    }

    function _initRateGroup(uint rate_, uint ratePerSecond_) internal {
        pile.file("rate", rate_, ratePerSecond_);
        (, uint chi , uint ratePerSecond,) = pile.rates(rate_);
        assertEq(ratePerSecond, ratePerSecond_);
        assertEq(chi, ONE);
    }

    function testIncDebt() public {
        uint loan = 1;
        uint amount = 66 ether;
        // 12 % per year compound in seconds
        _setUpLoan(loan, 1000000003593629043335673583);
        _increaseDebt(loan, amount);

        hevm.warp(now + 1 days);
    }

    function testInitRateGroup() public {
        uint rate = 1000000003593629043335673583;
        uint ratePerSecond = rate;
        _initRateGroup(rate, ratePerSecond);
    }

    function testUpdateRateGroup() public {
        uint rate = 1000000003593629043335673583;
        uint initRatePerSecond = rate;
        _initRateGroup(rate, initRatePerSecond);

        hevm.warp(now + 1 days);

        uint newRatePerSecond = 1000000564701133626865910626;
        pile.file("rate", rate, newRatePerSecond);
        (, uint chi, uint ratePerSecond,) = pile.rates(rate);
        assertEq(ratePerSecond, 1000000564701133626865910626);
        assertEq(chi, 1000310537755655376744337012);
    }


    function testFailIncDebtNoAccrue() public {
        uint loan = 1;
        uint amount = 66 ether;
        // 12 % per year compound in seconds
        _setUpLoan(loan, 1000000003593629043335673583);

        hevm.warp(now + 1 days);

        _increaseDebt(loan, amount);
    }

    function testDecDebt() public {
        uint loan = 1;
        uint amount = 66 ether;
        // 12 % per year compound in seconds
        _setUpLoan(loan, 1000000003593629043335673583);
        _increaseDebt(loan, amount);
        _decreaseDebt(loan, amount);
    }

    function testFailDecDebtNoAccrue() public {
        uint loan = 1;
        uint amount = 66 ether;
        // 12 % per year compound in seconds
        _setUpLoan(loan, 1000000003593629043335673583);
        _increaseDebt(loan, amount);

        hevm.warp(now + 1 days);

        _decreaseDebt(loan, amount);
    }

    function testChangeRate() public {
        uint highRate = uint(1000001311675458706187136988); // 12 % per day
        uint lowRate = uint(1000000564701133626865910626); // 5 % / day

        uint loan = 1;
        uint principal = 100 ether;

        pile.file("rate", highRate, highRate);
        pile.file("rate", lowRate, lowRate);
        pile.setRate(loan, lowRate);
        pile.incDebt(loan, principal);
        assertDebt(loan, 100 ether);
        hevm.warp(now + 1 days);
        pile.drip(lowRate);
        pile.drip(highRate);
        assertDebt(loan, 105 ether);
        assertEq(pile.rateDebt(lowRate), 105 ether);
        assertEq(pile.rateDebt(highRate), 0);
        assertEq(pile.total(), 105 ether);

        // rate switch
        pile.changeRate(loan, highRate);
        assertDebt(loan, 105 ether);

        assertEq(pile.rateDebt(lowRate), 0);
        assertEq(pile.rateDebt(highRate), 105 ether);
        assertEq(pile.total(), 105 ether);

        hevm.warp(now + 1 days);

        //105 * 1.12 =117.6
        pile.drip(highRate);
        assertDebt(loan, 117.6 ether);
    }

    function testChangeRateNoDebt() public {
        uint highRate = uint(1000001311675458706187136988); // 12 % per day
        uint lowRate = uint(1000000564701133626865910626); // 5 % / day

        uint loan = 1;

        pile.file("rate", highRate, highRate);
        pile.file("rate", lowRate, lowRate);

        // set to 5%
        pile.setRate(loan, lowRate);
        assertDebt(loan, 0);
        hevm.warp(now + 1 days);
        pile.drip(lowRate);
        pile.drip(highRate);

        // rate switch without existing debt
        pile.changeRate(loan, highRate);
        assertDebt(loan, 0);

        // check if rate is 12%
        pile.incDebt(loan, 100 ether);
        hevm.warp(now + 1 days);
        pile.drip(highRate);
        assertDebt(loan, 112 ether);

    }

    function testFailSetRate() public {
        uint loan = 1;
        uint rate = uint(1000001311675458706187136988);
        // fail rate not initiated
        pile.setRate(loan, rate);
    }

    function testFailChangeRate() public {
        uint highRate = uint(1000001311675458706187136988); // 12 % per day
        uint lowRate = uint(1000000564701133626865910626); // 5 % / day
        uint loan = 1;

        pile.file("rate", highRate, highRate);
        // do not init lowRate
        pile.setRate(loan, highRate);
        // fail rate not initiated
        pile.changeRate(loan, lowRate);
    }

    function assertDebt(uint loan, uint should) public {
        uint debt = pile.debt(loan);
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
        pile.file("rate", rate, rate);
        pile.setRate(loan, rate);
        pile.drip(rate);
        pile.incDebt(loan, principal);

        // one day later
        hevm.warp(now + 1 days);
        pile.drip(rate);
        uint should = _calculateDebt(rate, principal, uint(3600*24));
        assertDebt(loan, should);
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

        pile.file("rate", rate, rate);
        pile.setRate(loan, rate);
        pile.drip(rate);
        pile.incDebt(loan, principal);
        assertDebt(loan, 66 ether);

        // two days later
        hevm.warp(now + 2 days);
        assertEq(pile.debt(loan), 72.765 ether); // 66 ether * 1,05**2
        pile.drip(rate);
        assertDebt(loan, 72.765 ether);
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
        pile.file("rate", rate, rate);
        pile.setRate(loan, rate);
        pile.drip(rate);
        pile.incDebt(loan, principal);

        assertDebt(loan, 66 ether);

        // on year later
        hevm.warp(now + 365 days);
        pile.drip(rate);
        assertDebt(loan, 73.92 ether); // 66 ether * 1,12
    }

    function testDrip() public {
        uint rate = uint(1000000564701133626865910626); // 5 % / day
        pile.file("rate", rate, rate);
        (uint debt1, uint rateIndex1, uint ratePerSecond1, uint lastUpdated1 ) = pile.rates(rate);
        assertEq(ratePerSecond1, rate);
        assertEq(lastUpdated1, now);
        assertEq(debt1, 0);

        // on day later
        hevm.warp(now + 1 days);

        (debt1,  rateIndex1,  ratePerSecond1,  lastUpdated1 ) = pile.rates(rate);
        assertEq(ratePerSecond1, rate);
        assertEq(debt1, 0);
        assertTrue(lastUpdated1 != now);

        pile.drip(rate);

        (uint debt2, uint rateIndex2, uint ratePerSecond2, uint lastUpdated2 ) = pile.rates(rate);
        assertEq(ratePerSecond2, rate);
        assertEq(lastUpdated2, now);
        assertEq(debt2, 0);
        assertTrue(rateIndex1 != rateIndex2);
    }

    function testMaxrateIndex() public {
        // rateIndex is uint, max value = (2^256)-1 = 1.1579209e+77
        // rateIndex initial 10^27
        uint rate = uint(1000000564701133626865910626); // 5 % / daily
        pile.file("rate", rate, rate);
        hevm.warp(now + 1050 days); // 1,05 ^1050 = 1.7732257e+22

        // init rateIndex 10^27 *  1.7732257 * 10^22  ~ rateIndex 10^49
        // rdiv operation needs to mul rateIndex with ONE (10^27)
        // therefore: 10^49 * 10^27 = 10^76 < 1.1579209e+77
        pile.drip(rate);
    }

    function testFailrateIndexTooHigh() public {
        // rateIndex is uint, max value = (2^256)-1 = 1.1579209e+77
        // rateIndex initial 10^27
        uint rate = uint(1000000564701133626865910626); // 5 % / daily
        pile.file("rate", rate, rate);
        hevm.warp(now + 1100 days); // 1,05 ^1100 = 2.0334288e+23

        // init rateIndex 10^27 *  2.0334288 * 10^23  ~ rateIndex 10^50
        // rdiv operation needs to mul rateIndex with ONE (10^27)
        // therefore: 10^50 * 10^27 = 10^77 same power as max value 1.1579209e+77
        pile.drip(rate);
    }

    function testMaxDebt() public {
        uint rate = uint(1000000564701133626865910626); // 5 % day
        pile.file("rate", rate, rate);
        uint loan = 1;
        uint principal = 1000000000  ether; // one billion 10^9 * 10^18 = 10^28
        pile.drip(rate);
        pile.setRate(loan, rate);
        pile.incDebt(loan, principal);

        // 150 days later
        hevm.warp(now + 1050 days); // produces max ~ rateIndex 10^49
        // debt ~ 10^27 * 10^49 =  10^76 (max uint is 10^77)
        pile.drip(rate);
    }

    function rad(uint wad_) internal pure returns (uint) {
        return wad_ * 10 ** 27;
    }

    function wad(uint rad_) internal pure returns (uint) {
        return rad_ / 10 ** 27;
    }
}
