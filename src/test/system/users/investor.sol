// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "../interfaces.sol";
import "ds-test/test.sol";

interface InvestorOperator {
    function supplyOrder(uint currencyAmount) external;
    function redeemOrder(uint redeemAmount) external;
    function disburse() external returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken);
}

contract Investor is DSTest {
    ERC20Like currency;
    ERC20Like token;

    InvestorOperator operator;
    address tranche;

    constructor(address operator_, address tranche_,  address currency_, address token_) {
        currency = ERC20Like(currency_);
        token = ERC20Like(token_);
        operator = InvestorOperator(operator_);
        tranche = tranche_;
    }

    function supplyOrder(uint currencyAmount) public {
        currency.approve(tranche, currencyAmount);
        operator.supplyOrder(currencyAmount);
    }

    function disburse() public returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken) {
       return operator.disburse();
    }

    function redeemOrder(uint tokenAmount) public {
        token.approve(tranche, tokenAmount);
        operator.redeemOrder(tokenAmount);
    }

}
