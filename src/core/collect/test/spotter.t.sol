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
import "../../test/mock/shelf.sol";
import "../../test/mock/nft.sol";
import "../spotter.sol";

contract SpotterTest is DSTest {
    PileMock pile;
    ShelfMock shelf;

    Spotter spotter;

    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, ONE), y / 2) / y;
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function setUp() public {
        pile = new PileMock();
        shelf = new ShelfMock();

        spotter = new Spotter(address(shelf), address(pile));
    }

    function testSeizable() public {
        uint loan = 1;
        shelf.setShelfReturn(address(123), loan, 120 ether, 100 ether);
        pile.setDebtOfReturn(110 ether);

        uint threshold = 12 * 10**26; // threshold 120%
        spotter.file("threshold", threshold);

        // 109% seizable
        assertTrue(spotter.seizable(loan));
        assertEq(pile.callsCollect(), 1);
        assertEq(shelf.adjustCalls(), 1);

        // 133.33% not seizable
        pile.setDebtOfReturn(90 ether);
        assertTrue(!spotter.seizable(loan));

        // 120% not seizable
        pile.setDebtOfReturn(100 ether);
        assertTrue(!spotter.seizable(loan));
    }

    function testSeizure() public {
        uint loan = 1;
        NFTMock nft = new NFTMock();
        nft.setOwnerOfReturn(address(spotter));

        shelf.setShelfReturn(address(nft), loan, 120 ether, 100 ether);
        pile.setDebtOfReturn(110 ether);

        uint threshold = 12 * 10**26; // threshold 120%
        spotter.file("threshold", threshold);

        spotter.seizure(loan);

        assertEq(spotter.nftOwner(loan), address(spotter));
        assertTrue(spotter.collectable(loan));
        assertEq(shelf.freeCalls(), 1);
        assertEq(shelf.usr(), address(spotter));
    }
}
