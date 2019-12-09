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

import "../collector.sol";

import "../tag.sol";
import "../spotter.sol";


contract Shelf is ShelfMock {
    mapping(uint => Loan) public loans;
    address registry;

    constructor(address registry_) public {
        registry = registry_;
    }
    function prepareLoan(uint loan, uint tokenId, uint price) public {
        loans[loan].tokenId = tokenId;
        loans[loan].price = price;

    }

    function free(uint loan, address usr) public  {
        NFTLike(registry).transferFrom(address(this), usr, loans[loan].tokenId);
    }
}


contract CollectorIntegrationTest is DSTest {
    PileMock pile;
    Shelf shelf;
    DeskMock desk;

    SimpleNFT nft;

    Collector collector;
    function setUp() public {

        nft = new SimpleNFT();
        //mock
        pile = new PileMock();
        shelf = new Shelf(address(nft));
        desk = new DeskMock();

        // collect contracts
        Tag tag = new Tag(address(pile));
        Spotter spotter = new Spotter(address(shelf), address(pile));
        collector = new Collector(address(spotter), address(tag), address(desk), address(pile));

    }

    function setUpLoan(uint loan, uint tokenId, uint price, uint debt) public {
        shelf.prepareLoan(loan, tokenId, price);
        nft.mint(address(shelf), tokenId);

        // define debt
        pile.setDebtOfReturn(debt);
    }

    function testCollect() public {
        uint loan = 1; uint tokenId = 123;
        uint price = 150; uint debt = 100;
        setUpLoan(loan,tokenId, price, debt);

    }
}


