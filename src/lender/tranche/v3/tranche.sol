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
  function transferFrom(address,address,uint) public returns (bool);
  function mint(address, uint) public;
  function burn(address, uint) public;
  function totalSupply() public view returns (uint);
}

contract TickerLike {
    function currentEpoch() public returns (uint);
}

contract Tranche is Math, Auth {
mapping (uint => Epoch) public epochs;
struct Epoch {
    uint totalRedeem;
    uint totalSupply;
    // denominated in WAD
    // percentage ONE == 100%
    uint redeemFulfillment;
    // denominated in WAD
    // percentage ONE == 100%
    uint supplyFulfillment;
    // tokenPrice after end of epoch
    uint tokenPrice; 
    mapping (address => uint) supplyCurrencyAmount;
    mapping (address => uint) redeemTokenAmount;
}

ERC20Like public currency;
ERC20Like public token;
TickerLike public ticker;
address self;

constructor(address currency_, address token_, address ticker_) public {
    wards[msg.sender] = 1;
    token = ERC20Like(token_);
    currency = ERC20Like(currency_);
    ticker = TickerLike(ticker_);
    self = address(this);
}

function supplyCurrencyAmount(uint epochID, address addr) public view returns (uint) {
    Epoch storage epoch = epochs[epochID];
    return epoch.supplyCurrencyAmount[addr];
}

function redeemTokenAmount(uint epochID, address addr) public view returns (uint) {
    Epoch storage epoch = epochs[epochID];
    return epoch.redeemTokenAmount[addr];
}

function balance() external view returns (uint) {
    return currency.balanceOf(self);
}

function tokenSupply() external view returns (uint) {
    return token.totalSupply();
}

function depend(bytes32 contractName, address addr) public auth {
    if (contractName == "token") { token = ERC20Like(addr); }
    if (contractName == "currency") { currency = ERC20Like(addr); }
    if (contractName == "ticker") { ticker = TickerLike(addr); }
    else revert();
}

// supplyOrder function can be used to place or revoke an supply 
function supplyOrder(uint epochID, uint supplyAmount) public {
    require((epochID >= ticker.currentEpoch()), "epoch-already-over");
    uint currentSupplyAmount = epochs[epochID].supplyCurrencyAmount[msg.sender];
    epochs[epochID].supplyCurrencyAmount[msg.sender] = supplyAmount;
    epochs[epochID].totalSupply = safeAdd(safeSub(epochs[epochID].totalSupply, currentSupplyAmount), supplyAmount);
    if (supplyAmount > currentSupplyAmount) {
        uint delta = safeSub(supplyAmount, currentSupplyAmount);
        require(currency.transferFrom(msg.sender, self, delta), "currency-transfer-failed");
        return;
    } 
    uint delta = safeSub(currentSupplyAmount, supplyAmount);
    if (delta > 0) {
       require(currency.transferFrom(self, msg.sender, delta), "currency-transfer-failed");
    }
}

// redeemOrder function can be used to place or revoke a redeem
function redeemOrder(uint epochID, uint redeemAmount) public {
    require((epochID >= ticker.currentEpoch()), "epoch-already-over");
    
    uint currentRedeemAmount = epochs[epochID].redeemTokenAmount[msg.sender];
    epochs[epochID].redeemTokenAmount[msg.sender] = redeemAmount;
    epochs[epochID].totalRedeem = safeAdd(safeSub(epochs[epochID].totalRedeem, currentRedeemAmount), redeemAmount);
    
     if (redeemAmount > currentRedeemAmount) {
        uint delta = safeSub(redeemAmount, currentRedeemAmount);
        require(token.transferFrom(msg.sender, self, delta), "token-transfer-failed");
        token.burn(self, redeemAmount);
        return;
    } 

    uint delta = safeSub(currentRedeemAmount, redeemAmount);
    if (delta > 0) {
      token.mint(msg.sender, delta);
      require(token.transferFrom(self, msg.sender, delta), "token-transfer-failed");
    }
}

// the disburse function can be used after an epoch is over to receive currency and tokens
function disburse(uint epochID) public {
    // require epoch is settled
    require((epochs[epochID].tokenPrice > 0), "epoch-not-settled-yet");
        
    uint currencyAmount = calcCurrencyDisbursement(epochID);
    uint tokenAmount = calcTokenDisbursement(epochID);
    
    epochs[epochID].supplyCurrencyAmount[msg.sender] = 0;
    if (currencyAmount > 0) {
        require(currency.transferFrom(self, msg.sender, currencyAmount), "currency-transfer-failed"); 
    }
    
    epochs[epochID].redeemTokenAmount[msg.sender] = 0;
    if (tokenAmount > 0) {
        token.mint(msg.sender, tokenAmount);
    }
}

function calcCurrencyDisbursement(uint epochID) public view returns(uint) {
    // currencyAmount = tokenAmount * percentage * tokenPrice 
    uint currencyAmount = rmul(epochs[epochID].tokenPrice, rmul(epochs[epochID].redeemFulfillment, epochs[epochID].redeemTokenAmount[msg.sender]));
    
    // currencyAmount += unused dai from supply
    return safeAdd(currencyAmount, rmul(safeSub(ONE, epochs[epochID].supplyFulfillment), epochs[epochID].supplyCurrencyAmount[msg.sender]));
}

function calcTokenDisbursement(uint epochID) public view returns(uint) {
    // todo consider TokenPrice
    // take currencyAmount from redeemOrder
    uint tokenAmount = rdiv(rmul(epochs[epochID].supplyFulfillment, epochs[epochID].supplyCurrencyAmount[msg.sender]), epochs[epochID].tokenPrice);

    // add leftovers from supplies
    return safeAdd(tokenAmount, rmul(safeSub(ONE, epochs[epochID].redeemFulfillment), epochs[epochID].redeemTokenAmount[msg.sender]));
}

// called by epoch coordinator in epoch execute method
function epochUpdate(uint epochID, uint supplyFulfillment_, uint redeemFulfillment_, uint tokenPrice_) public auth {
    epochs[epochID].supplyFulfillment = supplyFulfillment_;
    epochs[epochID].redeemFulfillment = redeemFulfillment_;
    epochs[epochID].tokenPrice = tokenPrice_;
}
}