// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/interest.sol";
import "./../../fixed_point.sol";

// contract without a state which defines the relevant formulars for the navfeed
contract Discounting is FixedPoint, Interest {

    function calcDiscount(uint discountRate, uint fv, uint normalizedBlockTimestamp, uint maturityDate_) public pure returns (uint result) {
        return rdiv(fv, rpow(discountRate, safeSub(maturityDate_, normalizedBlockTimestamp), ONE));
    }

    // calculate the future value based on the amount, maturityDate interestRate and recoveryRate
    function calcFutureValue(uint loanInterestRate, uint amount, uint maturityDate_, uint recoveryRatePD_) public view returns(uint) {
        uint nnow = uniqueDayTimestamp(block.timestamp);
        uint timeRemaining = 0;
        if (maturityDate_ > nnow) {
            timeRemaining = safeSub(maturityDate_, nnow);
        }

        return rmul(rmul(rpow(loanInterestRate, timeRemaining, ONE), amount), recoveryRatePD_);
    }
    function secureSub(uint x, uint y) public pure returns(uint) {
        if(y > x) {
            return 0;
        }
        return safeSub(x, y);
    }

    // normalizes a timestamp to round down to the nearest midnight (UTC)
    function uniqueDayTimestamp(uint timestamp) public pure returns (uint) {
        return (1 days) * (timestamp/(1 days));
    }

}