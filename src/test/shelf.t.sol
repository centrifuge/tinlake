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

import "../shelf.sol";
import "./mock/pile.sol";
import "./mock/title.sol";
import "./mock/nft.sol";
import "../appraiser.sol";


contract ShelfTest is DSTest {
    Shelf shelf;
    PileMock pile;
    NFTMock nft;
    Appraiser appraiser;
    TitleMock title;
    
    uint loan = 1;
    uint secondLoan = 2;

    uint principal = 5000;
    uint debt = 5500;
    uint appraisal = 6000;
    address someAddr = address(1);


    function setUp() public {
        pile = new PileMock();
        nft = new NFTMock();
        appraiser = new Appraiser();
        title = new TitleMock();
        shelf = createShelf(address(pile), address(appraiser), address(title));
    }

    function createShelf(address pile_, address appraiser_, address title_) internal returns (Shelf) {
        return new Shelf(pile_, appraiser_, title_);
    }

    function testSetupPrecondition() public {
        assertEq(shelf.bags(),0);
    }

    function testDeposit() public {
        uint256 tokenId = 55;
        nft.setOwnerOfReturn(address(this));
        appraiser.file(loan, appraisal);
        shelf.file(loan, address(nft), tokenId, principal);

        title.setOwnerOfReturn(address(this));
        shelf.deposit(loan, address(this));

        // check correct call nft.transferFrom
        assertEq(nft.transferFromCalls(), 1);
        assertEq(nft.from(), address(this));
        assertEq(nft.to(), address(shelf));
        assertEq(nft.tokenId(), tokenId);

        assertEq(shelf.bags(), appraisal);

        // check correct call pile.borrow
        assertEq(pile.wad(), principal);
        assertEq(pile.callsBorrow(),1);

    }
    function testFailDepositNoWhiteList() public {
        // loan is not whitelisted in shelf
        shelf.deposit(loan, msg.sender);
        assertEq(shelf.bags(), 0);
        assertEq(pile.wad(), 0);
        assertEq(pile.callsBorrow(),0);
    }

    function testFailDepositInvalidNFT() public {
        uint256 tokenId = 55;
        // invalid nft registry addr
        shelf.file(loan, someAddr, tokenId, principal);
        shelf.deposit(loan, msg.sender);
        assertEq(shelf.bags(), 0);
        assertEq(pile.wad(), 0);
        assertEq(pile.callsBorrow(),0);
    }

    function testFailDepositNotNFTOwner() public {
        uint256 tokenId = 55;
        // tokenId minted at some address
        nft.setOwnerOfReturn(someAddr);
        shelf.file(loan, address(nft), tokenId, principal);
        shelf.deposit(loan, msg.sender);
        assertEq(shelf.bags(), 0);
        assertEq(pile.wad(), 0);
        assertEq(pile.callsBorrow(),0);
    }

    function testFailRelease() public {
        // debt not repaid in pile
        pile.setLoanDebtReturn(100);
        shelf.release(loan, address(this));

    }
    function testRelease() public {
        testDeposit();
        nft.reset();
        pile.setLoanReturn(0, 0, 0, 0);
        shelf.release(1, address(this));
        assertEq(nft.from(), address(shelf));
        assertEq(nft.to(), address(this));
        assertEq(nft.transferFromCalls(), 1);
    }
    function testAdjust() public {
        // first nft
        uint256 token1 = 55;
        uint256 token2 = 44;

        nft.setOwnerOfReturn(address(shelf));
        shelf.file(loan, address(nft), token1, principal);
        appraiser.file(loan, 6000);
        assertEq(shelf.bags(), 0);

        // initial
        shelf.adjust(loan);
        assertEq(shelf.bags(), 6000);

        //  no change
        shelf.adjust(loan);
        assertEq(shelf.bags(), 6000);

        // decrease
        appraiser.file(loan, 5000);
        shelf.adjust(loan);
        assertEq(shelf.bags(), 5000);

        // increase
        appraiser.file(loan, 7000);
        shelf.adjust(loan);
        assertEq(shelf.bags(), 7000);

        // second nft
        uint apprFirstNFT = 7000;
        shelf.file(secondLoan, address(nft), token2, principal);
        appraiser.file(secondLoan, 10000);
        // not adjusted only nft 1 value
        assertEq(shelf.bags(), apprFirstNFT);

        // together with second
        shelf.adjust(secondLoan);
        assertEq(shelf.bags(), 10000 + apprFirstNFT);

        // decrease second nft
        appraiser.file(secondLoan, 8000);
        shelf.adjust(secondLoan);
        assertEq(shelf.bags(), 8000 + apprFirstNFT);


        // remove ownership for nft
        nft.setOwnerOfReturn(address(someAddr));
        shelf.adjust(secondLoan);
        assertEq(shelf.bags(),apprFirstNFT);
    }
}
