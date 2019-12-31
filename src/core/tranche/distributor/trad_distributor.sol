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
import "./distributor.sol";


contract CurrencyLike {
    function balanceOf(address) public returns(uint);
}

contract TraditionalDistributor is Distributor {
    // ERC20
    CurrencyLike public currency;

    function file(bytes32 what, address addr) public {
        if (what == "currency") {
            currency = CurrencyLike(currency);
        }  else revert();
    }

    function balance() public {
        if(manager.poolClosing() == true) {
            uint give = currency.balanceOf(manager.pile());
            repayTranches(give);
            return;
        }

        uint take = OperatorLike(manager.senior()).balance() + OperatorLike(manager.junior()).balance();
        borrowTranches(take);
    }
}
