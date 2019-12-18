// Copyright (C) 2018  Rain <rainbreak@riseup.net>, lucasvo
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

pragma solidity >=0.4.24;

import "ds-note/note.sol";

import { TitleOwned } from "./title.sol";

contract TokenLike{
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
}

contract BeansLike {
    uint public totalDebt;
    function debtOf(uint, uint) public view returns (uint);
    function burden(uint, uint) public view returns (uint);
    function initFee(uint, uint) public;
    function incLoanDebt(uint, uint, uint) public;
    function decLoanDebt(uint, uint, uint) public;
    function drip(uint) public;
}

// Pile
// Manages the balance for the currency ERC20 in which borrowers want to borrow.
contract Pile is DSNote, TitleOwned {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike public tkn;
    BeansLike public beans;

    // https://github.com/makerdao/dsr/blob/master/src/dsr.sol
    struct Loan {
        uint balance;
        uint fee;
    }

    mapping (uint => Loan) public loans_;

    function loans(uint loan) public view returns (uint debt, uint balance, uint fee)  {
        uint debt = beans.debtOf(loan, loans_[loan].fee);
        return (debt, loans_[loan].balance, loans_[loan].fee);
    }

    function Debt() public view returns (uint debt) {
        return beans.totalDebt();
    }

    uint public Balance;
    address public lender;

    constructor(address tkn_, address title_, address beans_) TitleOwned(title_) public {
        wards[msg.sender] = 1;
        tkn = TokenLike(tkn_);
        beans = BeansLike(beans_);
    }

    function depend(bytes32 what, address data) public auth {
        if (what == "lender") { lender = data; }
    }

    function file(uint loan, uint fee_, uint balance_) public auth note {
        loans_[loan].fee = fee_;
        loans_[loan].balance = balance_;
    }

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function burden(uint loan) public view returns (uint) {
        return beans.burden(loan, loans_[loan].fee);
    }

    // --- Pile ---
    // want() is the the additional token that must be supplied for the Pile to cover all outstanding loans_.
    // If negative, it's the reserves the Pile has.
    function want() public view returns (int) {
        return int(Balance) - int(tkn.balanceOf(address(this))); // safemath
    }

    function initLoan(uint loan, uint wad) internal {
        beans.drip(loans_[loan].fee);
        beans.incLoanDebt(loan, loans_[loan].fee, wad);
        loans_[loan].balance = add(loans_[loan].balance, wad);
        Balance = add(Balance, wad);
    }

    // borrow() creates a debt by the borrower for the specified amount.
    function borrow(uint loan, uint wad) public auth note {
        initLoan(loan, wad);
    }

    // withdraw() moves token from the Pile to the user
    function withdraw(uint loan, uint wad, address usr) public owner(loan) note {
        require(wad <= loans_[loan].balance, "only max. balance can be withdrawn");
        loans_[loan].balance -= wad;
        Balance -= wad;
        tkn.transferFrom(address(this), usr, wad);
    }

    function balanceOf(uint loan) public view returns (uint) {
        return loans_[loan].balance;
    }

    function collect(uint loan) public {
        beans.drip(loans_[loan].fee);
    }


    // recovery used for defaulted loans_
    function recovery(uint loan, address usr, uint wad) public auth {
        doRepay(loan, usr, wad);

        uint loss = beans.debtOf(loan, loans_[loan].fee);
        beans.decLoanDebt(loan, loans_[loan].fee, loss);
    }

    function doRepay(uint loan, address usr, uint wad) internal {
        collect(loan);

        uint fee = loans_[loan].fee;
        uint debt = beans.debtOf(loan, fee);

        // only repay max loan debt
        if (wad > debt) {
            wad = debt;
        }

        tkn.transferFrom(usr, address(this), wad);
        beans.decLoanDebt(loan, fee, wad);
        tkn.approve(lender, wad);
    }

    // repay() a certain amount of token from the user to the Pile
    function repay(uint loan, uint wad) public owner(loan) note {
        // moves currency from usr to pile and reduces debt
        require(loans_[loan].balance == 0,"before repay loan needs to be withdrawn");
        doRepay(loan, msg.sender, wad);
    }

    function debtOf(uint loan) public returns (uint) {
        return beans.debtOf(loan, loans_[loan].fee);
    }
}
