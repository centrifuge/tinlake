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

contract TokenLike {
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
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

    // https://github.com/makerdao/dsr/blob/master/src/dsr.sol
    struct Fee {
        uint debt;
        uint chi;
        uint speed; // Accumulation per second
        uint48 rho; // Last time the rate was accumulated
    }

    struct Loan {
        uint pie; // Used to calculate debt
        uint balance;
        uint fee;
    }

    mapping (uint => Fee) public fees;
    mapping (uint => Loan) public loans_;

    function loans(uint loan) public view returns (uint debt, uint balance, uint fee)  {
        uint debt = debtOf(loan);
        return (debt, loans_[loan].balance, loans_[loan].fee);
    }

    uint public Balance;
    uint public Debt;

    address public lender;

    constructor(address tkn_, address title_) TitleOwned(title_) public {
        wards[msg.sender] = 1;
        tkn = TokenLike(tkn_);
        fees[0].chi = ONE;
        fees[0].speed = ONE;
    }

    function depend(bytes32 what, address data) public auth {
        if (what == "lender") { lender = data; }
    }

    function file(uint loan, uint fee_, uint balance_) public auth note {
        loans_[loan].fee = fee_;
        loans_[loan].balance = balance_;
    }

    function file(uint fee, uint speed_) public auth note {
        require(speed_ != 0);
        fees[fee].speed = speed_;
        fees[fee].chi = ONE;
        fees[fee].rho = uint48(now);
        drip(fee);
    }

    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
    }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, ONE), y / 2) / y;
    }
    function div(uint x, uint y) internal pure returns (uint z) {
        z = x / y;
    }

    function incDebt(uint fee, uint wad) internal {
        fees[fee].debt = add(fees[fee].debt, wad);
        Debt = add(Debt, wad);

    }

    function decDebt(uint fee, uint wad) internal {
        fees[fee].debt = sub(fees[fee].debt, wad);
        Debt = sub(Debt, wad);
    }

    function burden(uint loan) public view returns (uint) {
        uint fee = loans_[loan].fee;
        uint chi = fees[fee].chi;

        if (now >= fees[fee].rho) {
            (chi, ,) = compounding(fee);
        }
        uint debt = rmul(loans_[loan].pie, chi);
        return debt;
    }

    function compounding(uint fee) public view returns (uint,uint,uint) {
        uint48 rho = fees[fee].rho;
        require(now >= rho);
        uint speed = fees[fee].speed;

        uint chi = fees[fee].chi;
        uint debt = fees[fee].debt;

        // compounding in seconds
        uint latest = rmul(rpow(speed, now - rho, ONE), chi);
        uint chi_ = rdiv(latest, chi);
        uint wad = rmul(debt, chi_)-debt;
        return (latest, chi_, wad);

    }

    // --- Fee Accumulation ---
    function drip(uint fee) public {
        (uint latest, , uint wad) = compounding(fee);
        fees[fee].chi = latest;

        fees[fee].rho = uint48(now);
        incDebt(fee, wad);
    }

    function collect(uint loan) public {
        uint fee = loans_[loan].fee;
        if (now >= fees[fee].rho) {
            drip(fee);
        }
    }

    // --- Pile ---
    // want() is the the additional token that must be supplied for the Pile to cover all outstanding loans_.
    // If negative, it's the reserves the Pile has.
    function want() public view returns (int) {
        return int(Balance) - int(tkn.balanceOf(address(this))); // safemath
    }

    function initLoan(uint loan,uint wad, uint chi) internal {
        loans_[loan].pie  = rdiv(wad, chi);
        loans_[loan].balance = add(loans_[loan].balance, wad);
        Balance = add(Balance, wad);
    }

    // borrow() creates a debt by the borrower for the specified amount.
    function borrow(uint loan, uint wad) public auth note {
        uint fee = loans_[loan].fee;
        drip(fee);

        initLoan(loan, wad,fees[fee].chi);

        incDebt(fee, wad);
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

    // repay() a certain amount of token from the user to the Pile
    function repay(uint loan, uint wad) public owner(loan) note {
        // moves currency from usr to pile and reduces debt
        require(loans_[loan].balance == 0,"before repay loan needs to be withdrawn");
        collect(loan);

        // only repay max loan debt
        uint debt = debtOf(loan);
        if (wad > debt) {
            wad = debt;
        }

        tkn.transferFrom(msg.sender, address(this), wad);

        uint chi = getChi(loan);
        uint pie_ = rdiv(wad, chi);
        loans_[loan].pie = sub(loans_[loan].pie, pie_);

        decDebt(loans_[loan].fee, wad);
        tkn.approve(lender, wad);
    }

    function debtOf(uint loan) public view returns(uint) {
        uint chi = getChi(loan);
        return rmul(loans_[loan].pie, chi);
    }

    function getChi(uint loan) internal view returns(uint) {
        return fees[loans_[loan].fee].chi;
    }
}
