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

pragma solidity >= 0.5.12;

import "ds-test/test.sol";

import "../shelf.sol";
import "./mock/title.sol";
import "./mock/nft.sol";
import "./mock/token.sol";
import "./mock/pile.sol";
import "./mock/ceiling.sol";

contract ShelfTest is DSTest {
    Shelf shelf;
    NFTMock nft;
    TitleMock title;
    TokenMock currency;
    PileMock pile;
    CeilingMock ceiling;

    function setUp() public {
        nft = new NFTMock();
        title = new TitleMock();
        currency = new TokenMock();
        pile = new PileMock();
        ceiling = new CeilingMock();
        shelf = new Shelf(address(currency), address(title), address(pile), address(ceiling));
    }

    function _issue(uint256 tokenId_, uint loan_) internal {
        title.setIssueReturn(loan_);
        title.setOwnerOfReturn(address(this));
    
        uint loanId = shelf.issue(address(nft), tokenId_);
        assertEq(loanId, loan_);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId_))), loan_);
    }

    function _lock(uint256 tokenId_, uint loan_) internal {
        shelf.lock(loan_, address(this));

        assertEq(nft.transferFromCalls(), 1);
        assertEq(nft.from(), address(this));
        assertEq(nft.to(), address(shelf));
        assertEq(nft.tokenId(), tokenId_);
    }

    function _borrow(uint loan_, uint wad_) internal {
        shelf.borrow(loan_, wad_);
        
        assertEq(ceiling.callsBorrow(), 1);
        assertEq(pile.callsAccrue(), 1);
        assertEq(pile.callsIncDebt(), 1);
        assertEq(shelf.balance(), wad_);
        uint loanBalance = shelf.balances(loan_);
        assertEq(loanBalance, wad_);
    }
    
    function _withdraw(uint loan_, uint wad_) internal {
        uint totalBalance = shelf.balance();
        uint loanBalance = shelf.balances(loan_);
        assertEq(totalBalance, wad_);
        assertEq(loanBalance, wad_);
        assertEq(pile.wad(), wad_);
        
        shelf.withdraw(loan_, wad_, address(this));

        assertEq(totalBalance-wad_, shelf.balance());
        assertEq(loanBalance-wad_, shelf.balances(loan_));
        assertEq(currency.calls("transferFrom"), 1);
        assertEq(currency.values_address("transferFrom_from"), address(shelf));
        assertEq(currency.values_address("transferFrom_to"), address(this));
        assertEq(currency.values_uint("transferFrom_amount"), wad_);
    }

    function _repay(uint loan_, uint wad_) internal {
        pile.setLoanDebtReturn(wad_);
        shelf.repay(loan_, wad_);

        assertEq(pile.callsAccrue(), 2);
        assertEq(pile.callsDecDebt(), 1);
        assertEq(shelf.balance(), 0);
        assertEq(shelf.balances(loan_), 0);
        assertEq(ceiling.callsRepay(), 1);
        assertEq(currency.calls("transferFrom"),2);
        assertEq(currency.values_address("transferFrom_from"),address(this));
        assertEq(currency.values_address("transferFrom_to"),address(shelf));
        assertEq(currency.values_uint("transferFrom_amount"),wad_);
    }

    function _recover(uint loan_, address usr_, uint wad_, uint debt_) internal {
        pile.setLoanDebtReturn(debt_);
        shelf.recover(loan_, usr_, wad_);

        assertEq(pile.callsAccrue(), 2);
        assertEq(pile.callsDecDebt(), 2);

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
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
    }

    function testFailBorrowCeilingReached() public {
        testLock();
        ceiling.setCeilingReached(true);
        _borrow(loan, wad);
    }

    function testFailBorrowNFTNotLocked() public {
        nft.setOwnerOfReturn(address(this));
        _issue(tokenId,loan);
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
    }

    function testWithdraw() public {
        testLock();
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
        _withdraw(loan, wad);
    }

    function testFailWithdrawNFTNotLocked() public {
        nft.setOwnerOfReturn(address(this));
        _issue(tokenId,loan);
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
        shelf.claim(loan, address(1));
        _withdraw(loan, wad);
    }

    function testFailWithdrawNoBalance() public {
        testLock();
        ceiling.setCeilingReached(false);
        _withdraw(loan, wad);
    }

    function testRepay() public {
        testLock();
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
        _withdraw(loan, wad);
        _repay(loan, wad);
    }

    function testRecover() public {
        testLock();
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
        _withdraw(loan, wad);
        _recover(loan, address(1), wad-10, wad);
    }

    function testFailRepayNFTNotLocked() public {
        nft.setOwnerOfReturn(address(this));
        _issue(tokenId,loan);
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
        _withdraw(loan, wad);
        shelf.claim(loan, address(1));
        _repay(loan, wad);
    }

    function testFailRepayNFTNoWithdraw() public {
        testLock();
        ceiling.setCeilingReached(false);
        _borrow(loan, wad);
        _repay(loan, wad);
    }

    function testSetupPrecondition() public {
        currency.setReturn("balanceOf", 0);
    }

    function testIssue() public {
       nft.setOwnerOfReturn(address(this));
       _issue(tokenId, loan);
    }

    function testMultiple_Issue() public {
        uint secondLoan = 2;
        nft.setOwnerOfReturn(address(this));

        _issue(tokenId, loan);

        shelf.close(loan);
        assertEq(shelf.nftlookup(keccak256(abi.encodePacked(address(nft), tokenId))), 0);
        assertEq(title.closeCalls(), 1);
        assertEq(title.tkn(), 1);

        _issue(tokenId, secondLoan);
    }

    function testFailMultiple_Issue() public {
        uint secondLoan = 2;
        nft.setOwnerOfReturn(address(this));

        _issue(tokenId, loan);
        _issue(tokenId, secondLoan);
    }

    function testLock() public {
        nft.setOwnerOfReturn(address(this));
        _issue(tokenId, loan);
        _lock(tokenId, loan);
    }

    function testFailLockNoWhiteList() public {
        _lock(tokenId, loan);
    }

    function testFailLockInvalidNFT() public {
        shelf.file(loan, address(1), tokenId);
        _lock(tokenId, loan);
    }

    function testFailDepositNotNFTOwner() public {
        // tokenId minted at some address
        nft.setOwnerOfReturn(address(1));
        shelf.file(loan, address(nft), tokenId);
        _lock(tokenId, loan);
    }

    function testUnlock() public {
        testLock();
        nft.reset();
        pile.setLoanDebtReturn(0);
        shelf.unlock(1);
        assertEq(nft.from(), address(shelf));
        assertEq(nft.to(), address(this));
        assertEq(nft.transferFromCalls(), 1);
    }

    function testFailUnlock() public {
        // debt not repaid in pile
        pile.setLoanDebtReturn(100);
        shelf.unlock(loan);

    }
}
