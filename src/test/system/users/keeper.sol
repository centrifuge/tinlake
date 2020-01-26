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

pragma solidity >=0.5.12;

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract Keeper {
    ERC20Like currency;
    CollectorLike collector;

    constructor (address collector_, address currency_) public {
        collector = CollectorLike(collector_);
        currency = ERC20Like(currency_);
    }

    function collect(uint loan) public {
        collector.collect(loan);
    }

    function approveCurrency(address usr, uint currencyPrice) public {
        currency.approve(usr, currencyPrice);
    }

}
