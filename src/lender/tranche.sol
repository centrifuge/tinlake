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
pragma experimental ABIEncoderV2;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";
import "./fixed_point.sol";


interface ERC20Like {
    function balanceOf(address) external view returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function mint(address, uint) external;
    function burn(address, uint) external;
    function totalSupply() external view returns (uint);
    function approve(address usr, uint amount) external;
}

interface ReserveLike {
    function deposit(uint amount) external;
    function payout(uint amount) external;
}

contract Tranche is Math, Auth, FixedPoint {
    mapping(uint => Epoch) public epochs;

    struct Epoch {
        // denominated in 10^27
        // percentage ONE == 100%
        Fixed27 redeemFulfillment;
        // denominated in 10^27
        // percentage ONE == 100%
        Fixed27 supplyFulfillment;
        // tokenPrice after end of epoch
        Fixed27 tokenPrice;
    }

    struct UserOrder {
        uint orderedInEpoch;
        uint supplyCurrencyAmount;
        uint redeemTokenAmount;
    }

    mapping(address => UserOrder) public users;

    uint public  totalSupply;
    uint public  totalRedeem;

    ERC20Like public currency;
    ERC20Like public token;
    ReserveLike public reserve;

    address self;

    uint public currentEpoch;
    bool public waitingForUpdate  = false;
    uint public lastEpochExecuted;


    constructor(address currency_, address token_) public {
        wards[msg.sender] = 1;
        currentEpoch = 1;
        lastEpochExecuted = 0;
        token = ERC20Like(token_);
        currency = ERC20Like(currency_);
        self = address(this);
    }

    function balance() external view returns (uint) {
        return currency.balanceOf(self);
    }

    function tokenSupply() external view returns (uint) {
        return token.totalSupply();
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "token") {token = ERC20Like(addr);}
        else if (contractName == "currency") {currency = ERC20Like(addr);}
        else if (contractName == "reserve") {reserve = ReserveLike(addr);}
        else revert();
    }

    // supplyOrder function can be used to place or revoke an supply
    function supplyOrder(address usr, uint newSupplyAmount) public auth {
        require(users[usr].orderedInEpoch == 0 || users[usr].orderedInEpoch == currentEpoch, "disburse required");
        users[usr].orderedInEpoch = currentEpoch;

        uint currentSupplyAmount = users[usr].supplyCurrencyAmount;

        users[usr].supplyCurrencyAmount = newSupplyAmount;

        totalSupply = safeAdd(safeSub(totalSupply, currentSupplyAmount), newSupplyAmount);

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
    function redeemOrder(address usr, uint newRedeemAmount) public auth {
        require(users[usr].orderedInEpoch == 0 || users[usr].orderedInEpoch == currentEpoch, "disburse required");
        users[usr].orderedInEpoch = currentEpoch;

        uint currentRedeemAmount = users[usr].redeemTokenAmount;
        users[usr].redeemTokenAmount = newRedeemAmount;
        totalRedeem = safeAdd(safeSub(totalRedeem, currentRedeemAmount), newRedeemAmount);

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

    function calcDisburse(address usr) public view returns(uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) {
        return calcDisburse(usr, lastEpochExecuted);
    }

    function calcDisburse(address usr, uint endEpoch) public view returns(uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) {
        uint epochIdx = users[usr].orderedInEpoch;

        uint payoutCurrencyAmount = 0;
        uint payoutTokenAmount = 0;

        // no disburse possible in this epoch
        if (users[usr].orderedInEpoch == currentEpoch) {
            return (payoutCurrencyAmount, payoutTokenAmount, users[usr].supplyCurrencyAmount, users[usr].redeemTokenAmount);
        }

        if (endEpoch > lastEpochExecuted) {
            // it is only possible to disburse epochs which are already over
            endEpoch = lastEpochExecuted;
        }

        uint remainingSupplyCurrency = users[usr].supplyCurrencyAmount;
        uint remainingRedeemToken = users[usr].redeemTokenAmount;
        uint amount = 0;

        while(epochIdx <= endEpoch && (remainingSupplyCurrency != 0 || remainingRedeemToken != 0 )){
            if(remainingSupplyCurrency != 0) {
                amount = rmul(remainingSupplyCurrency, epochs[epochIdx].supplyFulfillment.value);
                // supply currency payout in token
                if (amount != 0) {
                    payoutTokenAmount = safeAdd(payoutTokenAmount, rdiv(amount, epochs[epochIdx].tokenPrice.value));
                    remainingSupplyCurrency = safeSub(remainingSupplyCurrency, amount);
                }
            }

            if(remainingRedeemToken != 0) {
                amount = rmul(remainingRedeemToken, epochs[epochIdx].redeemFulfillment.value);
                // redeem token payout in currency
                if (amount != 0) {
                    payoutCurrencyAmount = safeAdd(payoutCurrencyAmount, rmul(amount, epochs[epochIdx].tokenPrice.value));
                    remainingRedeemToken = safeSub(remainingRedeemToken, amount);
                }
            }
            epochIdx = safeAdd(epochIdx, 1);
        }

        return (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken);

    }

    // the disburse function can be used after an epoch is over to receive currency and tokens
    function disburse(address usr) public auth returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) {
        return disburse(usr, lastEpochExecuted);
    }

    // the disburse function can be used after an epoch is over to receive currency and tokens
    function disburse(address usr,  uint endEpoch) public auth returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency, uint remainingRedeemToken) {
        require(users[usr].orderedInEpoch <= lastEpochExecuted);

        (payoutCurrencyAmount, payoutTokenAmount,
         remainingSupplyCurrency, remainingRedeemToken) = calcDisburse(usr, endEpoch);

        users[usr].supplyCurrencyAmount = remainingSupplyCurrency;
        users[usr].redeemTokenAmount = remainingRedeemToken;

        // remaining orders are placed in the current epoch to allow
        // which allows to change the order and therefore receive it back
        // this is only possible if all previous epochs are disbursed (no orders reserved)
        if (endEpoch == safeSub(currentEpoch, 1)) {
            users[usr].orderedInEpoch = currentEpoch;
        } else {
            users[usr].orderedInEpoch = endEpoch;
        }

        if (payoutCurrencyAmount > 0) {
            require(currency.transferFrom(self, usr, payoutCurrencyAmount), "currency-transfer-failed");
        }

        if (payoutTokenAmount > 0) {
            require(token.transferFrom(self, usr, payoutTokenAmount), "token-transfer-failed");
        }
        return (payoutCurrencyAmount, payoutTokenAmount, remainingSupplyCurrency, remainingRedeemToken);

    }

    // called by epoch coordinator in epoch execute method
    function epochUpdate(uint supplyFulfillment_, uint redeemFulfillment_, uint tokenPrice_, uint epochSupplyCurrency, uint epochRedeemCurrency) public auth {
        require(waitingForUpdate == true);
        waitingForUpdate = false;

        uint epochID = safeSub(currentEpoch, 1);

        epochs[epochID].supplyFulfillment.value = supplyFulfillment_;
        epochs[epochID].redeemFulfillment.value = redeemFulfillment_;
        epochs[epochID].tokenPrice.value = tokenPrice_;

        // currency needs to be converted to tokenAmount with current token price
        uint redeemInToken = 0;
        uint supplyInToken = 0;
        if(tokenPrice_ > 0) {
            supplyInToken = rdiv(epochSupplyCurrency, tokenPrice_);
            redeemInToken = rdiv(epochRedeemCurrency, tokenPrice_);
        }
        adjustTokenBalance(epochID, supplyInToken, redeemInToken);
        adjustCurrencyBalance(epochID, epochSupplyCurrency, epochRedeemCurrency);

        totalSupply = safeAdd(safeSub(totalSupply, epochSupplyCurrency), rmul(epochSupplyCurrency, safeSub(ONE, epochs[epochID].supplyFulfillment.value)));
        totalRedeem = safeAdd(safeSub(totalRedeem, redeemInToken), rmul(redeemInToken, safeSub(ONE, epochs[epochID].redeemFulfillment.value)));

        lastEpochExecuted = safeAdd(lastEpochExecuted, 1);
    }
    function closeEpoch() public auth returns (uint totalSupplyCurrency_, uint totalRedeemToken_) {
        require(waitingForUpdate == false);
        currentEpoch = safeAdd(currentEpoch, 1);
        waitingForUpdate = true;
        return (totalSupply, totalRedeem);
    }


    // adjust token balance after epoch execution -> min/burn tokens
    function adjustTokenBalance(uint epochID, uint epochSupply, uint epochRedeem) internal {
        // mint token amount for supply
        uint mintAmount = 0;
        if (epochs[epochID].tokenPrice.value > 0) {
            mintAmount = rdiv(rmul(epochSupply, epochs[epochID].supplyFulfillment.value), epochs[epochID].tokenPrice.value);
        }

      // burn token amount for redeem
        uint burnAmount = rmul(epochRedeem, epochs[epochID].redeemFulfillment.value);
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

    // additional minting of tokens produces a dilution of all token holders
    // interface is required for adapters
    function mint(address usr, uint amount) public auth {
        token.mint(usr, amount);
    }

    // adjust currency balance after epoch execution -> receive/send currency from/to reserve
    function adjustCurrencyBalance(uint epochID, uint epochSupply, uint epochRedeem) internal {
        // currency that was supplied in this epoch
        uint currencySupplied = rmul(epochSupply, epochs[epochID].supplyFulfillment.value);
        // currency required for redemption
        uint currencyRequired = rmul(rmul(epochRedeem, epochs[epochID].redeemFulfillment.value), epochs[epochID].tokenPrice.value);

        if (currencySupplied > currencyRequired) {
            // send surplus currency to reserve
            uint diff = safeSub(currencySupplied, currencyRequired);
            currency.approve(address(reserve), diff);
            reserve.deposit(diff);
            return;
        }
        uint diff = safeSub(currencyRequired, currencySupplied);
        if (diff > 0) {
            // get missing currency from reserve
            reserve.payout(diff);
        }
    }
}
