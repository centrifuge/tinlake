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
import "../../test/mock/manager.sol";

import "../../test/simple/nft.sol";

import "../collector.sol";

import "../tag.sol";
import "../spotter.sol";
import "../collector.sol";

contract Shelf is ShelfMock {
    function free(uint loan, address usr) public  {
        NFTLike(shelfReturn.registry).transferFrom(address(this), usr, shelfReturn.tokenId);
    }
}

contract CollectorIntegrationTest is DSTest {
    PileMock pile;
    Shelf shelf;
    ManagerMock manager;

    SimpleNFT nft;

    Collector collector;
    Spotter spotter;
    Tag tag = new Tag(address(pile));

    function setUp() public {
        nft = new SimpleNFT();
        //mock
        pile = new PileMock();
        shelf = new Shelf();
        manager = new ManagerMock();

        // collect contracts
        tag = new Tag(address(pile));
        spotter = new Spotter(address(shelf), address(pile));
        collector = new Collector(address(spotter), address(tag), address(manager), address(pile));

        // auth
        spotter.rely(address(collector));

        // spotter threshold 120%
        uint threshold = 12 * 10**26;
        spotter.file("threshold", threshold);

    }

    function setUpLoan(uint loan, uint tokenId, uint price, uint debt) public {
        // defines price and token Id
        shelf.setShelfReturn(address(nft), tokenId, price, 0);

        nft.mint(address(shelf), tokenId);

        // define debt
        pile.setDebtOfReturn(debt);
    }

    function testCollect() public {
        uint loan = 1; uint tokenId = 123;
        uint price = 150 ether; uint debt = 130 ether;
        setUpLoan(loan,tokenId, price, debt);

        // collect nft ratio 115% instead of >= 120%
        collector.collect(loan, address(this));

        // check nft transfer
        assertEq(nft.ownerOf(tokenId), address(this));

        // check contract calls
        assertEq(manager.callsBalance(), 1);
        assertEq(pile.callsRecovery(), 1);
        assertEq(pile.wad(), debt);
        assertEq(pile.loan(), loan);
    }

    function testCollectWithSpotter() public {
        uint loan = 1; uint tokenId = 123;
        uint price = 150 ether; uint debt = 100 ether;
        setUpLoan(loan,tokenId, price, debt);

        // 150% is enough threshold is 120%
        assertTrue(spotter.seizable(loan) == false);

        // increase debt to 115%
        pile.setDebtOfReturn(130 ether);
        assertTrue(spotter.seizable(loan) == true);

        // seizure nft by direct spotter call
        assertTrue(!spotter.collectable(loan));
        spotter.seizure(loan);
        assertTrue(spotter.collectable(loan));

        // collect nft
        collector.collect(loan, address(this));

        // new nft owner
        assertEq(nft.ownerOf(tokenId), address(this));
    }

}


