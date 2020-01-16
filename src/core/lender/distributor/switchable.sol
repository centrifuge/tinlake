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

import "ds-note/note.sol";
import { CurrencyLike, Distributor, TrancheLike } from "./base.sol";


contract SwitchableDistributor is Distributor {
    // ERC20
    CurrencyLike public currency;

    constructor(address shelf_, address currency_) Distributor(shelf_, currency_)  public {
        borrowFromTranches = false;
    }

    bool public borrowFromTranches;

    function file(bytes32 what, bool flag) public auth {
        if (what == "borrowFromTranches") {
            borrowFromTranches = flag;
        }  else revert();
    }

    function balance() public {
        if(borrowFromTranches) {
            uint currencyAmount = add(currency.balanceOf(address(senior)), currency.balanceOf(address(junior)));
            borrowTranches(currencyAmount);
            return;
        }
        uint repayAmount = currency.balanceOf(address(shelf));
        repayTranches(repayAmount);
    }
}
