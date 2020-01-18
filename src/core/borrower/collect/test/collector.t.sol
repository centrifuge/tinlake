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

pragma solidity >=0.5.12;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";

import "../../test/mock/shelf.sol";
import "../../test/mock/distributor.sol";
import "../../test/mock/nft.sol";
import "../../test/mock/pile.sol";

import "tinlake-registry/registry.sol";
import "../collector.sol";



contract CollectorTest is DSTest {
    ShelfMock shelf;
    PileMock pile;
    DistributorMock distributor;
    NFTMock   nft;

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
        assertEq(nft.transferFromCalls(), 1);
        assertEq(nft.to(), address(this));
        assertEq(nft.tokenId(), tokenId);
        assertEq(shelf.callsRecover(), 1);
        assertEq(shelf.wad(), price);
        assertEq(shelf.usr(), address(this));
    }
   
    function seize(uint loan) internal {
        collector.seize(loan);
        assertEq(shelf.callsClaim(), 1);
        assertEq(shelf.loan(), loan);
        assertEq(shelf.usr(), address(collector));   
    }
    
    function setUpLoan(uint loan, uint tokenId, uint debt) public {
        shelf.setLoanReturn(address(nft), tokenId);
        pile.setLoanDebtReturn(debt);
    }

    function testSeizeCollect() public {
        collector.relyCollector(address(this));
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(loan, tokenId, debt);

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
        setUpLoan(loan, tokenId, debt);
        
        collector.file(loan, address(0), price);
        threshold.set(loan, debt-1);
        seize(loan);
        collect(loan, tokenId, price);       
    }

    function testFailSeizeThresholdNotReached() public {
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(loan, tokenId, debt);

        threshold.set(loan, debt+1);
        collector.file(loan, address(this), price);
        seize(loan);
    }

    function testFailSeizeCollectUnauthorizedUser() public {
        uint loan = 1; uint tokenId = 123;
        uint debt = 100;
        uint price = debt-1;
        setUpLoan(loan, tokenId, debt);

        threshold.set(loan, debt+1);
        collector.file(loan, address(1), price);
        seize(loan);
        collect(loan, tokenId, price);
    }
}


