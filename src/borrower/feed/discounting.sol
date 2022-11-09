// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";

// contract without a state which defines the relevant formulars for the navfeed
contract Discounting is Math {
    function calcDiscount(uint256 discountRate, uint256 fv, uint256 normalizedBlockTimestamp, uint256 maturityDate_)
        public
        pure
        returns (uint256 result)
    {
        return rdiv(fv, rpow(discountRate, safeSub(maturityDate_, normalizedBlockTimestamp), ONE));
    }

    // calculate the future value based on the amount, maturityDate interestRate and recoveryRate
    function calcFutureValue(uint256 loanInterestRate, uint256 amount, uint256 maturityDate_, uint256 recoveryRatePD_)
        public
        view
        returns (uint256)
    {
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        uint256 timeRemaining = 0;
        if (maturityDate_ > nnow) {
            timeRemaining = safeSub(maturityDate_, nnow);
        }

        return rmul(rmul(rpow(loanInterestRate, timeRemaining, ONE), amount), recoveryRatePD_);
    }

    function secureSub(uint256 x, uint256 y) public pure returns (uint256) {
        if (y > x) {
            return 0;
        }
        return safeSub(x, y);
    }

    // normalizes a timestamp to round down to the nearest midnight (UTC)
    function uniqueDayTimestamp(uint256 timestamp) public pure returns (uint256) {
        return (1 days) * (timestamp / (1 days));
    }

    function rpow(uint256 x, uint256 n, uint256 base) public pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 { z := base }
                default { z := 0 }
            }
            default {
                switch mod(n, 2)
                case 0 { z := base }
                default { z := x }
                let half := div(base, 2) // for rounding.
                for { n := div(n, 2) } n { n := div(n, 2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0, 0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) }
                    x := div(xxRound, base)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }
}
