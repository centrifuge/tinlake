// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.3;

import "ds-test/test.sol";

import "../shelf.sol";
import "./mock/title.sol";
import "./mock/nft.sol";
import "./mock/token.sol";
import "./mock/pile.sol";
import "./mock/ceiling.sol";
import "./mock/subscriber.sol";
import "./mock/assessor.sol";
import "../../lender/test/mock/reserve.sol";


contract ShelfTest is DSTest {
    Shelf shelf;
    NFTMock nft;
    TitleMock title;
    TokenMock currency;
    PileMock pile;
    CeilingMock ceiling;
    ReserveMock reserve;
    AssessorMock assessor;

    function setUp() public {
        nft = new NFTMock();
        title = new TitleMock();
        currency = new TokenMock();
        pile = new PileMock();
        ceiling = new CeilingMock();
        assessor = new AssessorMock();
        reserve = new ReserveMock(address(currency));
        shelf = new Shelf(address(currency), address(title), address(pile), address(ceiling));
        shelf.depend("reserve", address(reserve));
        shelf.depend("assessor", address(assessor));

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

    function _borrow(uint loan_, uint currencyAmount_) internal {
        shelf.borrow(loan_, currencyAmount_);

        assertEq(ceiling.calls("borrow"), 1);
        assertEq(pile.calls("accrue"), 1);
        assertEq(pile.calls("incDebt"), 1);
        assertEq(shelf.balance(), currencyAmount_);
        uint loanBalance = shelf.balances(loan_);
        assertEq(loanBalance, currencyAmount_);
    }

    function _withdraw(uint loan_, uint currencyAmount_) internal {
        uint totalBalance = shelf.balance();
        uint loanBalance = shelf.balances(loan_);
        assertEq(totalBalance, currencyAmount_);
        assertEq(loanBalance, currencyAmount_);
        assertEq(pile.values_uint("incDebt_currencyAmount"), currencyAmount_);

        shelf.withdraw(loan_, currencyAmount_, address(this));

        assertEq(reserve.calls("balance"), 1);
        assertEq(totalBalance-currencyAmount_, shelf.balance());
        assertEq(loanBalance-currencyAmount_, shelf.balances(loan_));
        assertEq(currency.calls("transferFrom"), 1);
        assertEq(currency.values_address("transferFrom_from"), address(shelf));
        assertEq(currency.values_address("transferFrom_to"), address(this));
        assertEq(currency.values_uint("transferFrom_amount"), currencyAmount_);
    }

    function _repay(uint loan_, uint currencyAmount_) internal {
        pile.setReturn("debt_loan", currencyAmount_);
        shelf.repay(loan_, currencyAmount_);

        assertEq(reserve.calls("balance"), 2);
        assertEq(pile.calls("accrue"), 2);
        assertEq(pile.calls("decDebt"), 1);
        assertEq(shelf.balance(), 0);
        assertEq(shelf.balances(loan_), 0);
        assertEq(ceiling.calls("repay"), 1);
        assertEq(currency.calls("transferFrom"), 2);
        assertEq(currency.values_address("transferFrom_from"),address(this));
        assertEq(currency.values_address("transferFrom_to"),address(shelf));
        assertEq(currency.values_uint("transferFrom_amount"),currencyAmount_);
    }

    function _recover(uint loan_, address usr_, uint currencyAmount_, uint debt_) internal {
        pile.setReturn("debt_loan", debt_);
        shelf.recover(loan_, usr_, currencyAmount_);
        assertEq(pile.calls("accrue"), 2);
        assertEq(pile.calls("decDebt"), 1);

        assertEq(currency.calls("transferFrom"), 2);
        assertEq(currency.values_address("transferFrom_from"), usr_);
        assertEq(currency.values_address("transferFrom_to"), address(shelf));
        assertEq(currency.values_uint("transferFrom_amount"), currencyAmount_);
    }

    uint loan  = 1;
    uint currencyAmount = 100;
    uint256 tokenId = 55;

    function testBorrow() public {
        testLock();
        _borrow(loan, currencyAmount);
    }

    function testFailBorrowCeilingReached() public {
        testLock();
        ceiling.setFail("borrow", true);
        _borrow(loan, currencyAmount);
    }

    function testFailBorrowNFTNotLocked() public {
        nft.setReturn("ownerOf", address(this));
        _issue(tokenId,loan);
        _borrow(loan, currencyAmount);
    }

    function testWithdraw() public {
        testLock();
        _borrow(loan, currencyAmount);
        _withdraw(loan, currencyAmount);
    }

    function testFailWithdrawNFTNotLocked() public {
        nft.setReturn("ownerOf", address(this));
        _issue(tokenId,loan);
        _borrow(loan, currencyAmount);
        shelf.claim(loan, address(1));
        _withdraw(loan, currencyAmount);
    }

    function testFailWithdrawNoBalance() public {
        testLock();
        _withdraw(loan, currencyAmount);
    }

    function testRepay() public {
        testLock();
        _borrow(loan, currencyAmount);
        _withdraw(loan, currencyAmount);
        _repay(loan, currencyAmount);
    }

    function testRecover() public {
        testLock();
        _borrow(loan, currencyAmount);
        _withdraw(loan, currencyAmount);
        _recover(loan, address(1), currencyAmount-10, currencyAmount);
    }

    function testFailRepayNFTNotLocked() public {
        nft.setReturn("ownerOf", address(this));
        _issue(tokenId,loan);
        _borrow(loan, currencyAmount);
        _withdraw(loan, currencyAmount);
        shelf.claim(loan, address(1));
        _repay(loan, currencyAmount);
    }

    function testFailRepayNFTNoWithdraw() public {
        testLock();
        _borrow(loan, currencyAmount);
        _repay(loan, currencyAmount);
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

    function testEventSubscribe() public {
        SubscriberMock sub = new SubscriberMock();
        shelf.depend("subscriber", address(sub));
        testLock();
        _borrow(loan, currencyAmount);
        assertEq(sub.calls("borrowEvent"), 1);
        assertEq(sub.values_uint("borrowEvent"), loan);

        _withdraw(loan, currencyAmount);
        pile.setReturn("debt_loan", 0);
        shelf.unlock(loan);
        assertEq(sub.calls("unlockEvent"), 1);
        assertEq(sub.values_uint("unlockEvent"), loan);
    }
}
