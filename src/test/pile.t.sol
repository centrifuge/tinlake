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

import "../pile.sol";
import "./mock/token.sol";

contract Hevm {
    function warp(uint256) public;
}


contract PileTest is DSTest {
    Pile pile;
    TokenMock tkn;

    Hevm hevm;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        tkn = new TokenMock();
        pile = new Pile(address(tkn));
    }

    function testSetupPrecondition() public {
        tkn.setBalanceOfReturn(0);
        assertEq(pile.want(),0);
    }

    function borrow(uint loan, uint wad) public {
        uint totalBalance = pile.Balance();
        uint totalDebt = pile.Debt();

        pile.borrow(loan, wad);

        (uint debt, uint balance, uint fee, uint  chi) = pile.loans(loan);
        assertEq(pile.Balance(), totalBalance + wad);
        assertEq(pile.Debt(), totalBalance + wad);
        assertEq(debt, wad);
        assertEq(balance, wad);

    }

    function withdraw(uint loan, uint wad) public {
        uint totalBalance = pile.Balance();
        (,uint balance, ,) = pile.loans(loan);
        assertEq(balance,wad);

        pile.withdraw(loan,wad,address(this));

        assertEq(totalBalance-wad, pile.Balance());
        (,uint newBalance, ,) = pile.loans(loan);
        assertEq(balance-wad, newBalance);
        assertEq(tkn.transferFromCalls(),1);

        assertEq(tkn.dst(),address(pile));
        assertEq(tkn.src(),address(this));
        assertEq(tkn.wad(),wad);
    }

    function repay(uint loan, uint wad) public {
        uint totalDebt = pile.Debt();

        pile.repay(loan, wad, address(this));

        (uint debt,uint balance, ,) = pile.loans(loan);
        assertEq(totalDebt-wad, pile.Debt());
        assertEq(debt,0);
        assertEq(balance,0);

        assertEq(tkn.transferFromCalls(),2);
        assertEq(tkn.dst(),address(this));
        assertEq(tkn.src(),address(pile));
        assertEq(tkn.wad(),wad);

    }

    function testSimpleBorrow() public {
        uint loan  = 1;
        uint wad = 100;
        borrow(loan,wad);
    }

    function testSimpleWithdraw() public {
        uint loan  = 1;
        uint wad = 100;
        borrow(loan,wad);
        withdraw(loan, wad);
    }
    function testSimpleRepay() public {
        uint loan  = 1;
        uint wad = 100;
        borrow(loan,wad);
        withdraw(loan, wad);
        repay(loan, wad);
    }

    function rad(uint wad_) internal pure returns (uint) {
        return wad_ * 10 ** 27;
    }
    function wad(uint rad_) internal pure returns (uint) {
        return rad_ / 10 ** 27;
    }

    function testDrip() public {
        uint fee = uint(1000000564701133626865910626); // 5 % / day
        pile.file(fee, fee);
        (uint debt1, uint chi1, uint speed1, uint rho1 ) = pile.fees(fee);
        assertEq(speed1, fee);
        assertEq(rho1, now);
        assertEq(debt1, 0);
        hevm.warp(now + 1 days);

        (debt1,  chi1,  speed1,  rho1 ) = pile.fees(fee);
        assertEq(speed1, fee);
        assertEq(debt1, 0);
        assertTrue(rho1 != now);

        pile.drip(fee);

        (uint debt2, uint chi2, uint speed2, uint rho2 ) = pile.fees(fee);
        assertEq(speed2, fee);
        assertEq(rho2, now);
        assertEq(debt2, 0);


        assertTrue(chi1 != chi2);
    }


    function testSingleFee() public {
        uint fee = uint(1000000564701133626865910626); // 5 % / day
        pile.file(fee, fee);
        uint loan = 1;
        uint principal = 66 ether;
        pile.file(loan, fee, 0);
        borrow(loan, principal);
        (uint debt1,,uint fee1 ,uint chi1) = pile.loans(loan);
        assertEq(debt1, 66 ether);
        assertEq(fee, fee1);

        // two days later
        hevm.warp(now + 2 days);
        pile.collect(loan);

        (uint debt2,,uint fee2 ,uint chi2) = pile.loans(loan);
        assertEq(debt2, 72.765 ether); // 66 ether * 1,05**2
        assertEq(fee, fee2);
        assertTrue(chi1 != chi2);

    }

    function checkDebt(uint loan, uint wad) public {
        (uint debt,,,) = pile.loans(loan);
        assertEq(debt, wad);
    }

    function testDoubleDripFee() public {
        uint fee = uint(1000000564701133626865910626); // 5 % / daily
        pile.file(fee, fee);
        uint loan = 1;
        uint principal = 66 ether;
        pile.file(loan, fee, 0);
        borrow(loan, principal);
        (uint debt1,,uint fee1 ,uint chi1) = pile.loans(loan);
        assertEq(debt1, 66 ether);
        assertEq(fee, fee1);

        (, uint chiF, , ) = pile.fees(fee);

        uint time = now;
        // day 1
        hevm.warp(time + 1 days);
        pile.collect(loan);

        (,  chiF, , ) = pile.fees(fee);
        (uint debt2,,uint fee2 ,uint chi2) = pile.loans(loan);
        assertEq(debt2, 69.3 ether); // 66 ether * 1,05**1
        assertEq(fee, fee2);
        assertTrue(chi1 != chi2);

        // day 2
        hevm.warp(time + 3 days);
        pile.collect(loan);

        (,  chiF, , ) = pile.fees(fee);
        (uint debt3,,uint fee3 ,uint chi3) = pile.loans(loan);
        assertEq(debt3, 76.40325  ether); //  66 ether * 1,05**3
        assertEq(fee, fee3);
        assertTrue(chi2 != chi3);

    }
}
