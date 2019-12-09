//// Copyright (C) 2019 Centrifuge
//
//// This program is free software: you can redistribute it and/or modify
//// it under the terms of the GNU Affero General Public License as published by
//// the Free Software Foundation, either version 3 of the License, or
//// (at your option) any later version.
////
//// This program is distributed in the hope that it will be useful,
//// but WITHOUT ANY WARRANTY; without even the implied warranty of
//// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//// GNU Affero General Public License for more details.
////
//// You should have received a copy of the GNU Affero General Public License
//// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
//pragma solidity >=0.4.23;
//pragma experimental ABIEncoderV2;
//
//import "ds-test/test.sol";
//
//import "../../test/mock/pile.sol";
//import "../../test/mock/shelf.sol";
//import "../../test/mock/desk.sol";
//
//import "../../test/simple/nft.sol";
//
//import "../collector.sol";
//import "../tag.sol";
//import "../spotter.sol";
//
//contract CollectorIntegrationTest is DSTest {
//    PileMock pile;
//    ShelfMock shelf;
//    DeskMock desk;
//
//    Collector collector;
//
//    function setUp() public {
//        //mock
//        pile = new PileMock();
//        shelf = new ShelfMock();
//        desk = new DeskMock();
//
//        // collect contracts
//        Tag tag = new Tag(address(pile));
//        Spotter spotter = new Spotter(address(shelf), address(pile));
//        collector = new Collector(address(spotter), address(tag), address(desk), address(pile));
//    }
//
//    function testCollect() public {
//
//    }
//}
//
//
