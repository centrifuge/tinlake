// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-math/interest.sol";
import "./../../fixed_point.sol";

// contract without a state which defines the relevant formulars for the navfeed
contract Discounting is FixedPoint, Interest {

    function calcDiscount(uint discountRate, uint fv, uint normalizedBlockTimestamp, uint maturityDate_) public pure returns (uint result) {
        return rdiv(fv, rpow(discountRate, safeSub(maturityDate_, normalizedBlockTimestamp), ONE));
    }

    // calculate the future value based on the amount, maturityDate interestRate and recoveryRate
    function calcFutureValue(uint loanInterestRate, uint amount, uint maturityDate_, uint recoveryRatePD_) public view returns(uint) {
        return rmul(rmul(rpow(loanInterestRate, safeSub(maturityDate_, uniqueDayTimestamp(block.timestamp)), ONE), amount), recoveryRatePD_);
    }
    function secureSub(uint x, uint y) public pure returns(uint) {
        if(y > x) {
            return 0;
        }
        return safeSub(x, y);
    }

    function uniqueDayTimestamp(uint timestamp) public pure returns (uint) {
        return (1 days) * (timestamp/(1 days));
    }

}