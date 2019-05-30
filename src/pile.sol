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

contract TokenLike {
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
}

// Pile 
// Manages the balance for the currency ERC20 in which borrowers want to borrow. 
contract Pile is DSNote {
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
        uint debt;
        uint balance;
        uint fee;
        uint chi;
    }

    mapping (uint => Fee) public fees;
    mapping (uint => Loan) public loans;
    uint public Balance;
    uint public Debt;

    address public lender;

    constructor(address tkn_) public {
        wards[msg.sender] = 1;
        tkn = TokenLike(tkn_);

    }

    function setLender(address lender_) public auth {
        lender = lender_;
    }

    function file(uint loan, uint fee_, uint balance_) public auth note {
        loans[loan].fee = fee_;
        loans[loan].balance = balance_;
    }
    
    function file(uint fee, uint speed_) public auth note {
        fees[fee].speed = speed_; 
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

    // --- Fee Accumulation ---
    function drip(uint fee) public {
        uint48 rho = fees[fee].rho;
        uint speed = fees[fee].speed;
        uint chi = fees[fee].chi;
        uint debt = fees[fee].debt;
        require(now >= rho);
        uint chi_ = sub(rmul(rpow(speed, now - rho, ONE), chi), chi);
        uint wad = mul(debt, chi_);
        add(Debt, wad);
        fees[fee].debt = add(debt, wad);
        fees[fee].chi = add(chi, chi_);
        fees[fee].rho = uint48(now);
    }

    function collect(uint loan) public {
        uint fee = loans[loan].fee;
        if (now >= fees[fee].rho) {
            drip(fee);
        }
        uint chi_ = sub(fees[fee].chi, loans[loan].chi);
        uint wad = mul(loans[loan].debt, chi_);

        loans[loan].chi = add(loans[loan].chi, chi_);
        loans[loan].debt = add(loans[loan].debt, wad);
    }
        
   
    // --- Pile ---
    // want() is the the additional token that must be supplied for the Pile to cover all outstanding loans. If negative, it's the reserves the Pile has.
    function want() public view returns (int) {
        return int(Balance) - int(tkn.balanceOf(address(this))); // safemath
    }

    // borrow() creates a debt by the borrower for the specified amount. 
    function borrow(uint loan, uint wad) public auth note {
        collect(loan);
        
        uint fee = loans[loan].fee;
        fees[fee].debt = add(fees[fee].debt, wad);
        loans[loan].debt = add(loans[loan].debt, wad);
        loans[loan].balance = add(loans[loan].balance, wad);
        Balance = add(Balance, wad);
        Debt = add(Debt, wad);
    }

    // withdraw() moves token from the Pile to the user
    function withdraw(uint loan, uint wad, address usr) public auth note {
        require(wad <= loans[loan].balance, "only max. balance can be withdrawn");
        loans[loan].balance -= wad;
        Balance -= wad;
        tkn.transferFrom(address(this), usr, wad);
    }

    function balanceOf(uint loan) public view returns (uint) {
        return loans[loan].balance;
    }

    // repay() a certain amount of token from the user to the Pile
    function repay(uint loan, uint wad, address usr) public auth note {
        // moves currency from usr to pile and reduces debt
        require(loans[loan].balance == 0,"before repay loan needs to be withdrawn");
        collect(loan);
        tkn.transferFrom(usr, address(this), wad);
        loans[loan].debt = sub(loans[loan].debt, wad);
        Debt -= wad;

        tkn.approve(lender,wad);
    }

    function debtOf(uint loan) public returns(uint) {
        return loans[loan].debt;
    }
}
