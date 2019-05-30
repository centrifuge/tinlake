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

import "../reception.sol";
import "./mock/pile.sol";
import "./mock/title.sol";
import "./mock/desk.sol";
import "./mock/shelf.sol";



contract ReceptionUser {
    Reception reception;
    constructor (Reception reception_) public {
        reception = reception_;
    }
    function doBorrow(uint loan, address deposit) public {
        return reception.borrow(loan, deposit);
    }

    function doRepay(uint loan, uint wad, address payedBy, address nftTo) public {
        return reception.repay(loan,wad,payedBy,nftTo);
    }
}

contract ReceptionTest is DSTest {

    Reception reception;

    DeskMock desk;
    ShelfMock shelf;
    TitleMock title;
    PileMock pile;

    ReceptionUser user1;
    ReceptionUser user2;


    function setUp() public {
        desk = new DeskMock();
        title = new TitleMock();
        shelf = new ShelfMock();
        pile = new PileMock();

        reception = new Reception(address(desk),address(title),address(shelf), address(pile));
        user1 = new ReceptionUser(reception);
        user2 = new ReceptionUser(reception);
    }

    function testFailBorrowNotLoanOwner() public {
        user1.doBorrow(1, address(user1));
        assertEq(pile.callsBorrow(), 0);

    }

    function testBorrow() public {
        uint loan = 1;
        title.setOwnerOfReturn(address(user1));
        pile.setBalanceReturn(500);

        user1.doBorrow(loan, address(user1));

        assertEq(desk.callsBalance(), 1);
        assertEq(pile.callsWithdraw(), 1);
        assertEq(pile.loan(), loan);
        assertEq(pile.wad(), 500);

        assertEq(shelf.depositCalls(),1);
        assertEq(shelf.usr(), address(user1));

    }
}
