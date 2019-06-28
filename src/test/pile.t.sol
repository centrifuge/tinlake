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


contract PileTest is DSTest {
    Pile pile;
    TokenMock tkn;

    function setUp() public {

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
        assertEq(fee, 0);
        assertEq(fee, 0);
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
}
