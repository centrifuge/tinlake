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
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";

import "../../test/mock/pile.sol";
import "../tag.sol";

contract TagTest is DSTest {
    PileMock pile;
    Tag tag;

    // --- Math ---
    uint256 constant ONE = 10 ** 27;

    function setUp() public {
        pile = new PileMock();
        tag = new Tag(address(pile));
    }

    function testSimpleTag() public {
        uint loan = 1;
        pile.setDebtOfReturn(100 ether);
        assertEq(tag.price(loan), 100 ether);
        assertEq(pile.callsCollect(), 1);
        assertEq(pile.loan(), 1);
    }

    function testDiscount() public {
        pile.setDebtOfReturn(100 ether);

        // only 80% of debt required as global discount
        tag.reduce(80 * ONE/100);
        // specific discount 70%
        tag.reduce(2,70 * ONE/100);

        assertEq(tag.price(1), 80 ether);
        assertEq(tag.price(2), 70 ether);
    }
}


