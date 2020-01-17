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
import "../pool.sol";
import "../../test/mock/pile.sol";

contract PricePoolTest is DSTest {
    PricePool pricePool;
    PileMock pile;

    function setUp() public {
        pile = new PileMock();
        pricePool = new PricePool();
        pricePool.depend("pile", address(pile));
    }

    function testPriceValue() public {
        pile.setTotalReturn(100 ether);
        assertEq(pricePool.totalValue(), 100 ether);
        // assume 10% defaults
        pricePool.file("riskscore", 9 * 10**26);
        assertEq(pricePool.totalValue(), 90 ether);
    }
}
