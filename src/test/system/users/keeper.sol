// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract Keeper {
    ERC20Like currency;
    CollectorLike collector;

    constructor (address collector_, address currency_) {
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
