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

import { Admit } from "../admit.sol";
import "./mock/title.sol";
import "./mock/shelf.sol";

contract AdmitTest is DSTest {
    Admit admit;
    TitleMock title;
    ShelfMock shelf;

    address self;

    function setUp() public {
        self = address(this);

        title = new TitleMock();
        shelf = new ShelfMock();

        admit = new Admit(address(title),address(shelf));
    }

    function testAdmit() public {
        uint loan = 97;
        address registry = address(1);
        uint nft = 2;
        uint principal = 3;

        title.setIssueReturn(loan);

        uint loanR = admit.admit(registry, nft, principal, self);

        assertEq(shelf.fileCalls(), 1);
        assertEq(title.issueCalls(), 1);
        assertEq(loanR, loan);
    }

    function testUpdate() public {

    }
}
