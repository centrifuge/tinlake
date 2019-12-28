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

pragma solidity >=0.4.24;

contract OperatorMock {

    uint public callsBalance;
    uint public callsBorrow;
    uint public callsRepay;
    uint public callsDebt;

    uint public debtOf; function setDebtOf(uint debt_) public {debtOf=debt_;}
    uint public balanceOf; function setBalance(uint balance_) public {balanceOf=balance_;}

    uint public supplyRate;
    uint public rate;
    uint public reserve;
    int public loanAmount;

    function debt() public returns (uint) {
        callsDebt++;
        return debtOf;
    }

    function balance() public returns (uint) {
        callsBalance++;
        return balanceOf;
    }

    function repay(address usr, uint currencyAmount) public {
        callsRepay++;
        balanceOf = balanceOf + currencyAmount;
        debtOf = debtOf - currencyAmount;
    }

    function borrow(address usr, uint borrowAmount) public {
        callsBorrow++;
        balanceOf = balanceOf - borrowAmount;
        debtOf = debtOf + borrowAmount;
    }
}
