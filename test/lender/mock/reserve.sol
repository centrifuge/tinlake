// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-auth/auth.sol";
import "../../../test/mock/mock.sol";

interface CurrencyLike {
    function transferFrom(address from, address to, uint256 amount) external;
    function balanceOf(address usr) external returns (uint256);
}

contract ReserveMock is Mock, Auth {
    CurrencyLike public currency;

    constructor(address currency_) {
        wards[msg.sender] = 1;
        currency = CurrencyLike(currency_);
    }

    function file(bytes32, uint256 currencyAmount) public {
        values_uint["borrow_amount"] = currencyAmount;
    }

    function balance() public returns (uint256) {
        return call("balance");
    }

    function totalBalance() public view returns (uint256) {
        return values_return["balance"];
    }

    function totalBalanceAvailable() public view returns (uint256) {
        return values_return["totalBalanceAvailable"];
    }

    function hardDeposit(uint256 amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(msg.sender, address(this), amount);
    }

    function hardPayout(uint256 amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }

    function deposit(uint256 amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(msg.sender, address(this), amount);
    }

    function payout(uint256 amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }

    function payoutForLoans(uint256 amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }
}
