// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "../../test/mock/shelf.sol";
import "../../test/mock/reserve.sol";
import "../../test/mock/nft.sol";
import "../../test/mock/pile.sol";

import "../collector.sol";


contract CollectorTest is DSTest {
    ShelfMock       shelf;
    PileMock        pile;
    ReserveMock     resreve;
    NFTMock         nft;

    Collector    collector;

    function setUp() public {
        nft = new NFTMock();
        shelf = new ShelfMock();
        pile = new PileMock();
        resreve = new ReserveMock();

        collector = new Collector(address(shelf), address(pile), address(nft));
        collector.depend("reserve", address(resreve));
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

        nft.setThreshold(loan, debt-1);
        collector.file("loan", loan, address(this), price);
        seize(loan);
        collect(loan, tokenId, price);
    }

    function testSeizeCollectAnyUser() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(tokenId, debt);

        collector.file("loan", loan, address(0), price);
        nft.setThreshold(loan, debt-1);
        seize(loan);
        collect(loan, tokenId, price);
    }

    function testFailSeizeThresholdNotReached() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(tokenId, debt);

        nft.setThreshold(loan, debt+1);
        collector.file("loan", loan, address(this), price);
        seize(loan);
    }

    function testFailSeizeCollectUnauthorizedUser() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(tokenId, debt);

        nft.setThreshold(loan, debt+1);
        collector.file("loan", loan, address(1), price);
        seize(loan);
        collect(loan, tokenId, price);
    }

    function testFailNoPriceDefined() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        setUpLoan(tokenId, debt);

        nft.setThreshold(loan, debt-1);

        seize(loan);
        collect(loan, tokenId, 0);
    }
}


