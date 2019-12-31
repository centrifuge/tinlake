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
import "../../test/mock/desk.sol";

import "../../test/simple/nft.sol";
import "tinlake-registry/registry.sol";
import "../collector.sol";

contract Shelf is ShelfMock {
    function free(uint loan, address usr) public  {
        NFTLike(shelfReturn.registry).transferFrom(address(this), usr, shelfReturn.tokenId);
    }
}

contract CollectorTest is DSTest {
    PileMock  pile;
    Shelf     shelf;
    DeskMock  desk;

    SimpleNFT nft;

    Collector    collector;
    PushRegistry threshold;

    function setUp() public {
        nft = new SimpleNFT();
        pile = new PileMock();
        shelf = new Shelf();
        desk = new DeskMock();

        threshold = new PushRegistry();
        collector = new Collector(address(desk), address(pile), address(shelf), address(threshold));
    }

    function setUpLoan(uint loan, uint tokenId, uint debt) public {
        // defines price and token Id
        shelf.setShelfReturn(address(nft), tokenId, 0, 0);
        nft.mint(address(shelf), tokenId);
        // define debt
        pile.setDebtOfReturn(debt);
    }

    function testSeize() public {
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        setUpLoan(loan,tokenId, debt);

        threshold.set(loan, debt);
        collector.seize(loan);
        assertEq(shelf.claimCalls(), 1);
        assertEq(shelf.loan(), loan);
        assertEq(shelf.usr(), address(collector));
    }
/*
    function testCollect() public {
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        setUpLoan(loan,tokenId, debt);

        collector.file(loan, address(this), debt-1);
        collector.collect(loan);

        // check nft transfer
        assertEq(nft.ownerOf(tokenId), address(this));

        // check contract calls
        assertEq(desk.callsBalance(), 1);
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
*/
}


