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

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import "tinlake-math/math.sol";
import "../ceiling/creditline.sol";
import "./mock/pile.sol";

contract CreditLineTest is Math, DSTest {
    CreditLine creditLine;
    PileMock pile;

    function setUp() public {
        pile = new PileMock();
        creditLine = new CreditLine(address(pile));
    }

    function testBorrow() public {
        uint loanId = 1;
        uint initial = 100;
        uint debt = 50;
                
        pile.setLoanDebtReturn(debt);
        creditLine.file(loanId, initial);

        uint borrowAmount = sub(initial, debt);
        creditLine.borrow(loanId, borrowAmount);
        pile.setLoanDebtReturn(add(debt, borrowAmount));
        assertEq(creditLine.ceiling(loanId), initial - (borrowAmount + debt));
    }

    function testFailBorrowAmountTooHigh() public {
        uint loanId = 1;
        uint initial = 100;
        uint debt = 50;
                
        pile.setLoanDebtReturn(debt);
        creditLine.file(loanId, initial);

        uint borrowAmount = add(initial, 10);
        creditLine.borrow(loanId, borrowAmount);
    }
}
