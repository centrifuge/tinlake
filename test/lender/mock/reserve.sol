// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-auth/auth.sol";
import "../../../test/mock/mock.sol";

interface CurrencyLike {
    function transferFrom(address from, address to, uint amount) external;
    function balanceOf(address usr) external returns (uint);
}

contract ReserveMock is Mock, Auth {
    CurrencyLike public currency;
    constructor(address currency_) {
        wards[msg.sender] = 1;
        currency = CurrencyLike(currency_);
    }

    function file(bytes32 , uint currencyAmount) public {
        values_uint["borrow_amount"] = currencyAmount;
    }

    function balance() public returns (uint) {
        return call("balance");
    }

    function totalBalance() public view returns (uint) {
        return values_return["balance"];
    }

    function totalBalanceAvailable() public view returns (uint) {
        return values_return["totalBalanceAvailable"];
    }

    function hardDeposit(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(msg.sender, address(this), amount);
    }

    function hardPayout(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }

    function deposit(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(msg.sender, address(this), amount);
    }

    function payout(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }

    function payoutForLoans(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }
}

