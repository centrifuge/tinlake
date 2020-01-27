// Copyright (C) 2020 Centrifuge

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

pragma solidity >=0.5.12;

import "ds-test/test.sol";

import "../../test/mock/shelf.sol";
import "../../test/mock/distributor.sol";
import "../../test/mock/nft.sol";
import "../../test/mock/pile.sol";

import "tinlake-registry/registry.sol";
import "../collector.sol";



contract CollectorTest is DSTest {
    ShelfMock       shelf;
    PileMock        pile;
    DistributorMock distributor;
    NFTMock         nft;

    Collector    collector;
    PushRegistry threshold;

    function setUp() public {
        nft = new NFTMock();
        shelf = new ShelfMock();
        pile = new PileMock();
        distributor = new DistributorMock();

        threshold = new PushRegistry();
        collector = new Collector(address(shelf), address(pile), address(threshold));
        collector.depend("distributor", address(distributor));
    }

    function collect(uint loan, uint tokenId, uint price) internal {
        collector.collect(loan, address(this));
        assertEq(nft.calls("transferFrom"), 1);
        assertEq(nft.values_address("transferFrom_to"), address(this));
        assertEq(nft.values_uint("transferFrom_tokenId"), tokenId);
        assertEq(shelf.calls("recover"), 1);
        assertEq(shelf.values_uint("recover_currencyAmount"), price);
        assertEq(shelf.values_address("recover_usr"), address(this));
    }

    function seize(uint loan) internal {
        collector.seize(loan);
        assertEq(shelf.calls("claim"), 1);
        assertEq(shelf.values_uint("claim_loan"), loan);
        assertEq(shelf.values_address("claim_usr"), address(collector));
    }

    function setUpLoan(uint tokenId, uint debt) public {
        shelf.setReturn("token", address(nft), tokenId);
        pile.setReturn("debt_loan", debt);
    }

    function testSeizeCollect() public {
        collector.relyCollector(address(this));
        uint loan = 1;
        uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(tokenId, debt);

        threshold.set(loan, debt-1);
        collector.file(loan, address(this), price);
        seize(loan);
        collect(loan, tokenId, price);
    }

    function testSeizeCollectAnyUser() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(tokenId, debt);

        collector.file(loan, address(0), price);
        threshold.set(loan, debt-1);
        seize(loan);
        collect(loan, tokenId, price);
    }

    function testFailSeizeThresholdNotReached() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(tokenId, debt);

        threshold.set(loan, debt+1);
        collector.file(loan, address(this), price);
        seize(loan);
    }

    function testFailSeizeCollectUnauthorizedUser() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(tokenId, debt);

        threshold.set(loan, debt+1);
        collector.file(loan, address(1), price);
        seize(loan);
        collect(loan, tokenId, price);
    }

    function testFailNoPriceDefined() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        setUpLoan(tokenId, debt);

        threshold.set(loan, debt-1);

        seize(loan);
        collect(loan, tokenId, 0);
    }
}


