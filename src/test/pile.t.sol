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
        assertEq(pile.want(),0);
    }
}
