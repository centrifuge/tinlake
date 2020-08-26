// Copyright (C) 2020 Centrifuge
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

pragma solidity >=0.5.15 <0.6.0;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";

contract ERC20Like {
    function balanceOf(address) public view returns (uint);

    function transferFrom(address, address, uint) public returns (bool);

    function mint(address, uint) public;

    function burn(address, uint) public;

    function totalSupply() public view returns (uint);
}

contract TickerLike {
    function currentEpoch() public returns (uint);
}

contract Tranche is Math, Auth {
    mapping(uint => Epoch) public epochs;

    struct Epoch {
        uint totalRedeem;
        uint totalSupply;
        // denominated in RAY
        // percentage ONE == 100%
        uint redeemFulfillment;
        // denominated in RAY
        // percentage ONE == 100%
        uint supplyFulfillment;
        // tokenPrice after end of epoch
        uint tokenPrice;
        mapping(address => uint) supplyCurrencyAmount;
        mapping(address => uint) redeemTokenAmount;
    }

    ERC20Like public currency;
    ERC20Like public token;
    TickerLike public ticker;
    address public reserve;

    address self;

    constructor(address currency_, address token_, address ticker_, address reserve_) public {
        wards[msg.sender] = 1;
        token = ERC20Like(token_);
        currency = ERC20Like(currency_);
        ticker = TickerLike(ticker_);
        reserve = reserve_;
        self = address(this);
    }

    function supplyCurrencyAmount(uint epochID, address addr) public view returns (uint) {
        return epochs[epochID].supplyCurrencyAmount[addr];
    }

    function redeemTokenAmount(uint epochID, address addr) public view returns (uint) {
        return epochs[epochID].redeemTokenAmount[addr];
    }

    function balance() external view returns (uint) {
        return currency.balanceOf(self);
    }

    function tokenSupply() external view returns (uint) {
        return token.totalSupply();
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "token") {token = ERC20Like(addr);}
        if (contractName == "currency") {currency = ERC20Like(addr);}
        if (contractName == "ticker") {ticker = TickerLike(addr);}
        if (contractName == "reserve") {reserve = addr;}
        else revert();
    }

    // supplyOrder function can be used to place or revoke an supply
    function supplyOrder(address usr, uint epochID, uint newSupplyAmount) public auth {
        require((epochID >= ticker.currentEpoch()), "epoch-already-over");
        require((epochs[epochID].tokenPrice == 0), "epoch-already-settled");

        uint currentSupplyAmount = epochs[epochID].supplyCurrencyAmount[usr];
        epochs[epochID].supplyCurrencyAmount[usr] = newSupplyAmount;
        epochs[epochID].totalSupply = safeAdd(safeSub(epochs[epochID].totalSupply, currentSupplyAmount), newSupplyAmount);
        if (newSupplyAmount > currentSupplyAmount) {
            uint delta = safeSub(newSupplyAmount, currentSupplyAmount);
            require(currency.transferFrom(usr, self, delta), "currency-transfer-failed");
            return;
        }
        uint delta = safeSub(currentSupplyAmount, newSupplyAmount);
        if (delta > 0) {
            require(currency.transferFrom(self, usr, delta), "currency-transfer-failed");
        }
    }

    // redeemOrder function can be used to place or revoke a redeem
    function redeemOrder(address usr, uint epochID, uint newRedeemAmount) public auth {
        require((epochID >= ticker.currentEpoch()), "epoch-already-over");
        require((epochs[epochID].tokenPrice == 0), "epoch-already-settled");

        uint currentRedeemAmount = epochs[epochID].redeemTokenAmount[usr];
        epochs[epochID].redeemTokenAmount[usr] = newRedeemAmount;
        epochs[epochID].totalRedeem = safeAdd(safeSub(epochs[epochID].totalRedeem, currentRedeemAmount), newRedeemAmount);

        if (newRedeemAmount > currentRedeemAmount) {
            uint delta = safeSub(newRedeemAmount, currentRedeemAmount);
            require(token.transferFrom(usr, self, delta), "token-transfer-failed");
            return;
        }

        uint delta = safeSub(currentRedeemAmount, newRedeemAmount);
        if (delta > 0) {
            require(token.transferFrom(self, usr, delta), "token-transfer-failed");
        }
    }

    // the disburse function can be used after an epoch is over to receive currency and tokens
    function disburse(address usr, uint epochID) public auth {
        // require epoch is settled
        require((epochs[epochID].tokenPrice > 0), "epoch-not-settled-yet");

        uint currencyAmount = calcCurrencyDisbursement(usr, epochID);
        uint tokenAmount = calcTokenDisbursement(usr, epochID);
        epochs[epochID].supplyCurrencyAmount[usr] = 0;
        if (currencyAmount > 0) {
            require(currency.transferFrom(self, usr, currencyAmount), "currency-transfer-failed");
        }

        epochs[epochID].redeemTokenAmount[usr] = 0;
        if (tokenAmount > 0) {
            require(token.transferFrom(self, usr, tokenAmount), "token-transfer-failed");
        }
    }

    function calcCurrencyDisbursement(address usr, uint epochID) public view returns (uint) {
        // currencyAmount = tokenAmount * percentage * tokenPrice
        uint currencyAmount = rmul(rmul(epochs[epochID].redeemTokenAmount[usr], epochs[epochID].redeemFulfillment), epochs[epochID].tokenPrice);
        // currencyAmount += unused dai from supply
        return safeAdd(currencyAmount, rmul(epochs[epochID].supplyCurrencyAmount[usr], safeSub(ONE, epochs[epochID].supplyFulfillment)));
    }

    function calcTokenDisbursement(address usr, uint epochID) public view returns (uint) {
        // take currencyAmount from redeemOrder
        uint tokenAmount = rdiv(rmul(epochs[epochID].supplyCurrencyAmount[usr], epochs[epochID].supplyFulfillment), epochs[epochID].tokenPrice);
        // add leftovers from supplies
        return safeAdd(tokenAmount, rmul(epochs[epochID].redeemTokenAmount[usr], safeSub(ONE, epochs[epochID].redeemFulfillment)));
    }

    // called by epoch coordinator in epoch execute method
    function epochUpdate(uint epochID, uint supplyFulfillment_, uint redeemFulfillment_, uint tokenPrice_) public auth {
        epochs[epochID].supplyFulfillment = supplyFulfillment_;
        epochs[epochID].redeemFulfillment = redeemFulfillment_;
        epochs[epochID].tokenPrice = tokenPrice_;

        adjustTokenBalance(epochID);
        adjustCurrencyBalance(epochID);
    }

    // adjust token balance after epoch execution -> min/burn tokens
    function adjustTokenBalance(uint epochID) internal {
        // burn amount of tokens for that epoch
        uint burnAmount = rmul(epochs[epochID].totalRedeem, epochs[epochID].redeemFulfillment);
        // mint amount of tokens for that epoch
        uint mintAmount = rdiv(rmul(epochs[epochID].totalSupply, epochs[epochID].supplyFulfillment), epochs[epochID].tokenPrice);
        // burn tokens that are not needed for disbursement
        if (burnAmount > mintAmount) {
            uint diff = safeSub(burnAmount, mintAmount);
            token.burn(self, diff);
            return;
        }
        // mint tokens that are required for disbursement
        uint diff = safeSub(mintAmount, burnAmount);
        if (diff > 0) {
            token.mint(self, diff);
        }
    }

    // adjust currency balance after epoch execution -> receive/send currency from/to reserve
    function adjustCurrencyBalance(uint epochID) internal {
        // currency that was supplied in this epoch
        uint currencySupplied = rmul(epochs[epochID].totalSupply, epochs[epochID].supplyFulfillment);
        // currency required for redemption
        uint currencyRequired = rmul(rmul(epochs[epochID].totalRedeem, epochs[epochID].redeemFulfillment), epochs[epochID].tokenPrice);

        if (currencySupplied > currencyRequired) {
            // send surplus currency to reserve
            uint diff = safeSub(currencySupplied, currencyRequired);
            require(currency.transferFrom(self, reserve, diff), "currency-transfer-failed");
            return;
        }
        uint diff = safeSub(currencyRequired, currencySupplied);
        if (diff > 0) {
            // get missing currency from reserve
            require(currency.transferFrom(reserve, self, diff), "currency-transfer-failed");
        }
    }

    function getTotalOrders(uint epochID) public returns(uint, uint) {
        return (epochs[epochID].totalRedeem , epochs[epochID].totalSupply);
    }
}
