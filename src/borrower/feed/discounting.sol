// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";

// contract without a state which defines the relevant formulars for the navfeed
contract Discounting is Math {

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

    function rpow(uint x, uint n, uint base) public pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }
}