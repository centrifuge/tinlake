// Copyright (C) 2019 lucasvo
//
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

//pragma solidity >=0.4.23;

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
    TitleMock title;

    uint loan = 1;
    uint secondLoan = 2;

    uint principal = 5000;
    uint debt = 5500;
    address someAddr = address(1);


    function setUp() public {
        pile = new PileMock();
        nft = new NFTMock();
        title = new TitleMock();
        shelf = createShelf(address(pile), address(title));
    }

    function createShelf(address pile_, address title_) internal returns (Shelf) {
        return new Shelf(pile_, title_);
    }

    function testSetupPrecondition() public {
        assertEq(shelf.bags(),0);
    }

    function testIssue() public {
        uint256 tokenId = 55;
        nft.setOwnerOfReturn(address(this));
        title.setIssueReturn(1);
        uint loan = shelf.issue(address(nft), tokenId);
        assertEq(loan, 1);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId))), 1);
    }

    function testMultipleIssue() public {
        uint256 tokenId = 55;
        nft.setOwnerOfReturn(address(this));
        title.setIssueReturn(1);
        uint loan = shelf.issue(address(nft), tokenId);
        assertEq(loan, 1);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId))), 1);

        title.setOwnerOfReturn(address(this));
        shelf.close(loan);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId))), 0);
        assertEq(title.closeCalls(), 1);
        assertEq(title.tkn(), 1);

        title.setIssueReturn(2);
        shelf.issue(address(nft), tokenId);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId))), 2);
    }

    function testFailMultipleIssue() public {
        uint256 tokenId = 55;
        nft.setOwnerOfReturn(address(this));
        title.setIssueReturn(1);
        shelf.issue(address(nft), tokenId);
        title.setIssueReturn(2);
        shelf.issue(address(nft), tokenId);
    }

    function testLock() public {
        testIssue();
        uint256 tokenId = 55;
        nft.setOwnerOfReturn(address(this));
        title.setOwnerOfReturn(address(this));
        shelf.lock(loan);

        // check correct call nft.transferFrom
        assertEq(nft.transferFromCalls(), 1);
        assertEq(nft.from(), address(this));
        assertEq(nft.to(), address(shelf));
        assertEq(nft.tokenId(), tokenId);
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

    function testFailUnlock() public {
        // debt not repaid in pile
        pile.setLoanDebtReturn(100);
        shelf.unlock(loan);

    }
    function testUnlock() public {
        testLock();
        nft.reset();
        pile.setLoanReturn(0, 0, 0);
        shelf.unlock(1);
        assertEq(nft.from(), address(shelf));
        assertEq(nft.to(), address(this));
        assertEq(nft.transferFromCalls(), 1);
    }
}
