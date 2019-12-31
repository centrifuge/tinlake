// Copyright (C) 2019 Centrifuge
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

import "./operator.sol";

contract QuantLike {
   function updateDebt(int) public;
}

// SeniorOperator
// Interface to the senior tranche. Uses the quant to keep track of the current debt towards the tranche. 
contract SeniorOperator is Operator {

    QuantLike public quant;

    constructor(address reserve_, address slicer_, address quant_) Operator(reserve_, slicer_) public {
        quant = QuantLike(quant_);
    }

    function repay(address usr, uint currencyAmount) public note auth {
        super.repay(usr, currencyAmount);
        quant.updateDebt(int(currencyAmount) * -1);
    }

    function borrow(address usr, uint currencyAmount) public note auth {
        super.borrow(usr, currencyAmount);
        quant.updateDebt(int(currencyAmount));
    }
}
