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
import "./mock/title.sol";
import "./mock/token.sol";
import "./mock/beans.sol";



contract PileTest is DSTest {
    Pile pile;
    TokenMock tkn;
    TitleMock title;
    BeansMock beans;

    function setUp() public {
        tkn = new TokenMock();
        title = new TitleMock();
        beans = new BeansMock();
        pile = new Pile(address(tkn), address(title), address(beans));
    }

    function testSetupPrecondition() public {
        tkn.setBalanceOfReturn(0);
        assertEq(pile.want(),0);
    }

    function borrow(uint loan, uint wad) public {
        uint totalBalance = pile.Balance();
        beans.setTotalDebtReturn(wad);
        beans.setLoanDebtReturn(wad);

        pile.borrow(loan, wad);

        (uint debt, uint balance, uint fee) = pile.loans(loan);
        assertEq(beans.callsIncLoanDebt(), 1);
        assertEq(pile.Balance(), totalBalance + wad);
        assertEq(pile.Debt(), wad);
        assertEq(balance, wad);
        assertEq(debt, wad);
    }

    function withdraw(uint loan, uint wad) public {
        uint totalBalance = pile.Balance();
        (, uint balance, ) = pile.loans(loan);
        assertEq(balance, wad);

        pile.withdraw(loan,wad,address(this));

        assertEq(totalBalance-wad, pile.Balance());
        (, uint newBalance, ) = pile.loans(loan);
        assertEq(balance-wad, newBalance);

        assertEq(tkn.transferFromCalls(), 1);
        assertEq(tkn.dst(), address(pile));
        assertEq(tkn.src(), address(this));
        assertEq(tkn.wad(), wad);
    }

    function repay(uint loan, uint wad) public {
        // pre state
        (,, uint fee) = pile.loans(loan);
        uint totalDebt = pile.Debt();

        pile.repay(loan, wad);
        beans.setTotalDebtReturn(0);
        beans.setLoanDebtReturn(0);

        // post state
        (uint debt, uint balance, ) = pile.loans(loan);

        assertEq(beans.callsDrip(), 2);
        assertEq(beans.callsDecLoanDebt(), 1);

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
        title.setOwnerOfReturn(address(this));
        borrow(loan, wad);
    }

    function testSimpleWithdraw() public {
        uint loan  = 1;
        uint wad = 100;
        title.setOwnerOfReturn(address(this));
        borrow(loan, wad);
        withdraw(loan, wad);
    }

    function testSimpleRepay() public {
        uint loan  = 1;
        uint wad = 100;
        title.setOwnerOfReturn(address(this));
        borrow(loan, wad);
        withdraw(loan, wad);
        repay(loan, wad);
    }

    function testBorrowRepayWithFee() public {
        uint fee = uint(1000000003593629043335673583); // 12 % per year
        uint loan = 1;
        uint principal = 100 ether;
        pile.file(loan, fee, 0);
        title.setOwnerOfReturn(address(this));

        borrow(loan, principal);
        withdraw(loan, principal);

        // one year later -> 1,12 * 100
        beans.setBurdenReturn(112 ether);
        beans.setTotalDebtReturn(112 ether);
        beans.setLoanDebtReturn(112 ether);

        uint debt = pile.burden(loan);
        repay(loan, debt);
    }

}
