// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";

/// @notice Discounting contract without a state which defines the relevant formulars for the navfeed
contract Discounting is Math {
    /// @notice calculates the discount for a given loan
    /// @param discountRate the discount rate
    /// @param fv the future value of the loan
    /// @param normalizedBlockTimestamp the normalized block time (each day to midnight)
    /// @param maturityDate the maturity date of the loan
    /// @return result discount for the loan
    function calcDiscount(uint256 discountRate, uint256 fv, uint256 normalizedBlockTimestamp, uint256 maturityDate)
        public
        pure
        returns (uint256 result)
    {
        return rdiv(fv, rpow(discountRate, safeSub(maturityDate, normalizedBlockTimestamp), ONE));
    }

    /// @notice calculate the future value based on the amount, maturityDate interestRate and recoveryRate
    /// @param loanInterestRate the interest rate of the loan
    /// @param amount of the loan (principal)
    /// @param maturityDate the maturity date of the loan
    /// @param recoveryRatePD the recovery rate together with the probability of default of the loan
    /// @return fv future value of the loan
    function calcFutureValue(uint256 loanInterestRate, uint256 amount, uint256 maturityDate, uint256 recoveryRatePD)
        public
        view
        returns (uint256 fv)
    {
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        uint256 timeRemaining = 0;
        if (maturityDate > nnow) {
            timeRemaining = safeSub(maturityDate, nnow);
        }

        return rmul(rmul(rpow(loanInterestRate, timeRemaining, ONE), amount), recoveryRatePD);
    }

    /// @notice substracts to values if the result smaller than 0 it returns 0
    /// @param x the first value (minuend)
    /// @param y the second value (subtrahend)
    /// @return result result of the subtraction
    function secureSub(uint256 x, uint256 y) public pure returns (uint256 result) {
        if (y > x) {
            return 0;
        }
        return safeSub(x, y);
    }

    /// @notice normalizes a timestamp to round down to the nearest midnight (UTC)
    /// @param timestamp the timestamp which should be normalized
    /// @return nTimstamp normalized timestamp
    function uniqueDayTimestamp(uint256 timestamp) public pure returns (uint256 nTimstamp) {
        return (1 days) * (timestamp / (1 days));
    }
    /// @notice rpow peforms a math pow operation with fixed point number
    /// adopted from ds-math
    /// @param x the base for the pow operation
    /// @param n the exponent for the pow operation
    /// @param base the base of the fixed point number
    /// @return z the result of the pow operation

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
