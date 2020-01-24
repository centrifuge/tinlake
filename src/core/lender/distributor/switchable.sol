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

pragma solidity >=0.5.12;

import "ds-note/note.sol";
import "./default.sol";

contract SwitchableDistributor is DefaultDistributor {
    bool public borrowFromTranches;

    constructor(address currency_) DefaultDistributor(currency_) public {
        borrowFromTranches = true;
    }

    function file(bytes32 what, bool flag) public auth {
        if (what == "borrowFromTranches") {
            borrowFromTranches = flag;
        }  else revert();
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "currency") {
            currency = CurrencyLike(currency);
        }  else super.depend(what, addr);
    }

    function balance() public {
        if(borrowFromTranches) {
            uint currencyAmount = junior.balance();
            if (address(senior) != address(0)) {
                currencyAmount = safeAdd(currencyAmount, senior.balance());
            }
            _borrowTranches(currencyAmount);
            return;
        }
        uint repayAmount = currency.balanceOf(address(shelf));
        _balanceTranches();
        _repayTranches(repayAmount);
    }
}
