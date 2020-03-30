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

pragma solidity >= 0.5.3;

import "ds-test/test.sol";

import "../shelf.sol";
import "./mock/title.sol";
import "./mock/nft.sol";
import "./mock/token.sol";
import "./mock/pile.sol";
import "./mock/ceiling.sol";
import "../../lender/test/mock/distributor.sol";

contract ShelfTest is DSTest {
    Shelf shelf;
    NFTMock nft;
    TitleMock title;
    TokenMock currency;
    PileMock pile;
    CeilingMock ceiling;
    DistributorMock distributor;

    function setUp() public {
        nft = new NFTMock();
        title = new TitleMock();
        currency = new TokenMock();
        pile = new PileMock();
        ceiling = new CeilingMock();
        distributor = new DistributorMock();
        shelf = new Shelf(address(currency), address(title), address(pile), address(ceiling));
        shelf.depend("distributor", address(distributor));
    }

    function _issue(uint256 tokenId_, uint loan_) internal {
        title.setReturn("issue", loan_);
        title.setReturn("ownerOf", address(this));

        uint loanId = shelf.issue(address(nft), tokenId_);
        assertEq(loanId, loan_);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId_))), loan_);
    }

    function _lock(uint256 tokenId_, uint loan_) internal {
        shelf.lock(loan_);

        assertEq(nft.calls("transferFrom"), 1);
        assertEq(nft.values_address("transferFrom_to"), address(shelf));
        assertEq(nft.values_address("transferFrom_from"), address(this));
        assertEq(nft.values_uint("transferFrom_tokenId"), tokenId_);

    }

    function _borrow(uint loan_, uint wad_) internal {
        shelf.borrow(loan_, wad_);

        assertEq(ceiling.calls("borrow"), 1);
        assertEq(pile.calls("accrue"), 1);
        assertEq(pile.calls("incDebt"), 1);
        assertEq(shelf.balance(), wad_);
        uint loanBalance = shelf.balances(loan_);
        assertEq(loanBalance, wad_);
    }

    function _withdraw(uint loan_, uint wad_) internal {
        uint totalBalance = shelf.balance();
        uint loanBalance = shelf.balances(loan_);
        assertEq(totalBalance, wad_);
        assertEq(loanBalance, wad_);
        assertEq(pile.values_uint("incDebt_currencyAmount"), wad_);

        shelf.withdraw(loan_, wad_, address(this));

        assertEq(distributor.calls("balance"), 1);
        assertEq(totalBalance-wad_, shelf.balance());
        assertEq(loanBalance-wad_, shelf.balances(loan_));
        assertEq(currency.calls("transferFrom"), 1);
        assertEq(currency.values_address("transferFrom_from"), address(shelf));
        assertEq(currency.values_address("transferFrom_to"), address(this));
        assertEq(currency.values_uint("transferFrom_amount"), wad_);
    }

    function _repay(uint loan_, uint wad_) internal {
        pile.setReturn("debt_loan", wad_);
        shelf.repay(loan_, wad_);

        assertEq(distributor.calls("balance"), 2);
        assertEq(pile.calls("accrue"), 2);
        assertEq(pile.calls("decDebt"), 1);
        assertEq(shelf.balance(), 0);
        assertEq(shelf.balances(loan_), 0);
        assertEq(ceiling.calls("repay"), 1);
        assertEq(currency.calls("transferFrom"), 2);
        assertEq(currency.values_address("transferFrom_from"),address(this));
        assertEq(currency.values_address("transferFrom_to"),address(shelf));
        assertEq(currency.values_uint("transferFrom_amount"),wad_);
    }

    function _recover(uint loan_, address usr_, uint wad_, uint debt_) internal {
        pile.setReturn("debt_loan", debt_);
        shelf.recover(loan_, usr_, wad_);
        assertEq(pile.calls("accrue"), 2);
        assertEq(pile.calls("decDebt"), 1);

        assertEq(currency.calls("transferFrom"), 2);
        assertEq(currency.values_address("transferFrom_from"), usr_);
        assertEq(currency.values_address("transferFrom_to"), address(shelf));
        assertEq(currency.values_uint("transferFrom_amount"), wad_);
    }

    uint loan  = 1;
    uint wad = 100;
    uint256 tokenId = 55;

    function testBorrow() public {
        testLock();
        _borrow(loan, wad);
    }

    function testFailBorrowCeilingReached() public {
        testLock();
        ceiling.setFail("borrow", true);
        _borrow(loan, wad);
    }

    function testFailBorrowNFTNotLocked() public {
        nft.setReturn("ownerOf", address(this));
        _issue(tokenId,loan);
        _borrow(loan, wad);
    }

    function testWithdraw() public {
        testLock();
        _borrow(loan, wad);
        _withdraw(loan, wad);
    }

    function testFailWithdrawNFTNotLocked() public {
        nft.setReturn("ownerOf", address(this));
        _issue(tokenId,loan);
        _borrow(loan, wad);
        shelf.claim(loan, address(1));
        _withdraw(loan, wad);
    }

    function testFailWithdrawNoBalance() public {
        testLock();
        _withdraw(loan, wad);
    }

    function testRepay() public {
        testLock();
        _borrow(loan, wad);
        _withdraw(loan, wad);
        _repay(loan, wad);
    }

    function testRecover() public {
        testLock();
        _borrow(loan, wad);
        _withdraw(loan, wad);
        _recover(loan, address(1), wad-10, wad);
    }

    function testFailRepayNFTNotLocked() public {
        nft.setReturn("ownerOf", address(this));
        _issue(tokenId,loan);
        _borrow(loan, wad);
        _withdraw(loan, wad);
        shelf.claim(loan, address(1));
        _repay(loan, wad);
    }

    function testFailRepayNFTNoWithdraw() public {
        testLock();
        _borrow(loan, wad);
        _repay(loan, wad);
    }

    function testSetupPrecondition() public {
        currency.setReturn("balanceOf", 0);
    }

    function testIssue() public {
        nft.setReturn("ownerOf", address(this));
       _issue(tokenId, loan);
    }

    function testMultiple_Issue() public {
        uint secondLoan = 2;
        nft.setReturn("ownerOf", address(this));

        _issue(tokenId, loan);

        shelf.close(loan);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId))), 0);
        assertEq(title.calls("close"), 1);
        assertEq(title.values_uint("close_loan"), 1);

        // issue second loan with same tokenId
        title.setReturn("issue", secondLoan);
        title.setReturn("ownerOf", address(this));

        uint loanId = shelf.issue(address(nft), tokenId);
        assertEq(loanId, secondLoan);
        nft.setReturn("ownerOf", secondLoan);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId))), secondLoan);
    }

    function testFailMultiple_Issue() public {
        uint secondLoan = 2;
        nft.setReturn("ownerOf", address(this));

        _issue(tokenId, loan);
        _issue(tokenId, secondLoan);
    }

    function testLock() public {
        nft.setReturn("ownerOf", address(this));
        _issue(tokenId, loan);
        _lock(tokenId, loan);
    }

    function testFailLockNoWhiteList() public {
        _lock(tokenId, loan);
    }

    function testFailDepositNotNFTOwner() public {
        // tokenId minted at some address
        nft.setReturn("ownerOf", address(1));
        _lock(tokenId, loan);
    }

    function testUnlock() public {
        testLock();

        pile.setReturn("debt_loan", 0);
        shelf.unlock(loan);

        assertEq(nft.calls("transferFrom"), 2);
        assertEq(nft.values_address("transferFrom_to"), address(this));
        assertEq(nft.values_address("transferFrom_from"), address(shelf));
        assertEq(nft.values_uint("transferFrom_tokenId"), tokenId);
    }

    function testFailUnlock() public {
        // debt not repaid in pile
        pile.setReturn("debt_loan", 100);
        shelf.unlock(loan);
    }
}
