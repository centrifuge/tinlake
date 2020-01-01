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
import "../../test/mock/nft.sol";

import "tinlake-registry/registry.sol";
import "../collector.sol";



contract CollectorTest is DSTest {
    PileMock  pile;
    ShelfMock shelf;
    DeskMock  desk;
    NFTMock   nft;

    Collector    collector;
    PushRegistry threshold;

    function setUp() public {
        nft = new NFTMock();
        pile = new PileMock();
        shelf = new ShelfMock();
        desk = new DeskMock();

        threshold = new PushRegistry();
        collector = new Collector(address(desk), address(pile), address(shelf), address(threshold));
    }

    function setUpLoan(uint loan, uint tokenId, uint debt) public {
        // defines price and token Id
        shelf.setShelfReturn(address(nft), tokenId, 0, 0);
        // define debt
        pile.setDebtOfReturn(debt);
    }

    function testSeizeFail() public {
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        setUpLoan(loan,tokenId, debt);

        threshold.set(loan, debt-1);
        collector.seize(loan);
    }

    function testSeizeCollect() public {
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        setUpLoan(loan, tokenId, debt);

        threshold.set(loan, debt);
        collector.file(loan, address(this), debt-1);
        collector.seize(loan);
        assertEq(shelf.claimCalls(), 1);
        assertEq(shelf.loan(), loan);
        assertEq(shelf.usr(), address(collector));

        collector.collect(loan);
        assertEq(nft.transferFromCalls(), 1);
        assertEq(nft.to(), address(this));
        assertEq(nft.tokenId(), tokenId);
        assertEq(pile.callsRecovery(), 1);
        assertEq(pile.wad(), debt-1);
        assertEq(pile.usr(), address(this));
    }
}


