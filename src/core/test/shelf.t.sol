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
import "./mock/title.sol";
import "./mock/nft.sol";
import "./mock/token.sol";
import "./mock/debt_register.sol";

contract ShelfTest is DSTest {
    Shelf shelf;
    NFTMock nft;
    TitleMock title;
    TokenMock tkn;
    DebtRegisterMock debt;
    CeilingMock ceiling;

    uint loan = 1;
    uint secondLoan = 2;

    uint debt = 5500;
    address someAddr = address(1);


    function setUp() public {
        nft = new NFTMock();
        title = new TitleMock();
        tkn = new TokenMock();
        debtRegister = new DebtRegisterMock();
        ceiling = new CeilingMock();
        shelf = new Shelf(address(tkn), address(title), address(debt), address(ceiling));
    }

    function borrow(uint loan, uint wad) public {
        uint totalBalance = pile.Balance();
        debtRegister.setTotalDebtReturn(wad);
        debtRegister.setLoanDebtReturn(wad);

        pile.borrow(loan, wad);

        (uint debt, uint balance, uint rate) = pile.loans(loan);
        assertEq(debtRegister.callsIncLoanDebt(), 1);
        assertEq(pile.Balance(), totalBalance + wad);
        assertEq(pile.Debt(), wad);
        assertEq(balance, wad);
        assertEq(debt, wad);
    }

    function withdraw(uint loan, uint wad) public {
        uint totalBalance = pile.Balance();
        (, uint balance, ) = pile.loans(loan);
        assertEq(balance, wad);

        pile.withdraw(loan,wad,address(this));

        assertEq(totalBalance-wad, pile.Balance());
        (, uint newBalance, ) = pile.loans(loan);
        assertEq(balance-wad, newBalance);

        assertEq(tkn.transferFromCalls(), 1);
        assertEq(tkn.dst(), address(pile));
        assertEq(tkn.src(), address(this));
        assertEq(tkn.wad(), wad);
    }

    function repay(uint loan, uint wad) public {
        // pre state
        (,, uint rate) = pile.loans(loan);
        uint totalDebt = pile.Debt();

        pile.repay(loan, wad);
        debtRegister.setTotalDebtReturn(0);
        debtRegister.setLoanDebtReturn(0);

        // post state
        (uint debt, uint balance, ) = pile.loans(loan);

        assertEq(debtRegister.callsDrip(), 2);
        assertEq(debtRegister.callsDecLoanDebt(), 1);

        assertEq(totalDebt-wad, pile.Debt());
        assertEq(debt,0);
        assertEq(balance,0);

        assertEq(tkn.transferFromCalls(),2);
        assertEq(tkn.dst(),address(this));
        assertEq(tkn.src(),address(pile));
        assertEq(tkn.wad(),wad);
    }

    function testSimpleBorrow() public {
        uint loan  = 1;
        uint wad = 100;
        title.setOwnerOfReturn(address(this));
        borrow(loan, wad);
    }

    function testSimpleWithdraw() public {
        uint loan  = 1;
        uint wad = 100;
        title.setOwnerOfReturn(address(this));
        borrow(loan, wad);
        withdraw(loan, wad);
    }

    function testSimpleRepay() public {
        uint loan  = 1;
        uint wad = 100;
        title.setOwnerOfReturn(address(this));
        borrow(loan, wad);
        withdraw(loan, wad);
        repay(loan, wad);
    }

    function testBorrowRepayWithRate() public {
        uint rate = uint(1000000003593629043335673583); // 12 % per year
        uint loan = 1;
        uint principal = 100 ether;
        pile.file(loan, rate, 0);
        title.setOwnerOfReturn(address(this));

        borrow(loan, principal);
        withdraw(loan, principal);

        // one year later -> 1,12 * 100
        debtRegister.setBurdenReturn(112 ether);
        debtRegister.setTotalDebtReturn(112 ether);
        debtRegister.setLoanDebtReturn(112 ether);

        uint debt = pile.getCurrentDebt(loan);
        repay(loan, debt);
    }


    function testSetupPrecondition() public {
        tkn.setBalanceOfReturn(0);
        assertEq(pile.want(),0);
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
