// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../interfaces.sol";
import "forge-std/Test.sol";

interface OperatorLike {
    function supplyOrder(uint256 currencyAmount) external;
    function redeemOrder(uint256 redeemAmount) external;
    function disburse()
        external
        returns (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        );
}

contract Investor is Test {
    ERC20Like currency;
    ERC20Like token;

    OperatorLike operator;
    address tranche;

    constructor(address operator_, address tranche_, address currency_, address token_) {
        currency = ERC20Like(currency_);
        token = ERC20Like(token_);
        operator = OperatorLike(operator_);
        tranche = tranche_;
    }

    function supplyOrder(uint256 currencyAmount) public {
        currency.approve(tranche, currencyAmount);
        operator.supplyOrder(currencyAmount);
    }

    function disburse()
        public
        returns (
            uint256 payoutCurrencyAmount,
            uint256 payoutTokenAmount,
            uint256 remainingSupplyCurrency,
            uint256 remainingRedeemToken
        )
    {
        return operator.disburse();
    }

    function redeemOrder(uint256 tokenAmount) public {
        token.approve(tranche, tokenAmount);
        operator.redeemOrder(tokenAmount);
    }
}
