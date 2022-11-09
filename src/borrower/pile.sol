// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2018  Rain <rainbreak@riseup.net>, Centrifuge
pragma solidity >=0.7.6;

import "tinlake-math/interest.sol";
import "tinlake-auth/auth.sol";

/// @notice Pile Contract to manage different interest groups of debt
/// The following is one implementation of a debt module. It keeps track of different buckets of interest rates and is optimized for many loans per interest bucket. It keeps track of interest
/// rate accumulators (chi values) for all interest rate categories. It calculates debt each
/// loan according to its interest rate category and pie value.
contract Pile is Auth, Interest {
    /// @notice Interest Rate Groups are identified by a `uint` and stored in a mapping
    mapping(uint256 => Rate) public rates;

    /// @notice mapping of all loan debts
    /// the debt is stored as pie
    /// pie is defined as pie = debt/chi therefore debt = pie * chi
    /// where chi is the accumulated interest rate index over time
    mapping(uint256 => uint256) public pie;

    /// @notice mapping from loan => rate
    mapping(uint256 => uint256) public loanRates;

    /// Events
    event IncreaseDebt(uint256 indexed loan, uint256 currencyAmount);
    event DecreaseDebt(uint256 indexed loan, uint256 currencyAmount);
    event SetRate(uint256 indexed loan, uint256 rate);
    event ChangeRate(uint256 indexed loan, uint256 newRate);
    event File(bytes32 indexed what, uint256 rate, uint256 value);

    constructor() {
        // pre-definition for loans without interest rates
        rates[0].chi = ONE;
        rates[0].ratePerSecond = ONE;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    /// @notice file manages different state configs for the pile
    /// only a ward can call this function
    /// @param what what config to change
    /// @param rate the interest rate group
    /// @param value the value to change
    function file(bytes32 what, uint256 rate, uint256 value) external auth {
        if (what == "rate") {
            require(value != 0, "rate-per-second-can-not-be-0");
            if (rates[rate].chi == 0) {
                rates[rate].chi = ONE;
                rates[rate].lastUpdated = uint48(block.timestamp);
            } else {
                drip(rate);
            }
            rates[rate].ratePerSecond = value;
        } else if (what == "fixedRate") {
            rates[rate].fixedRate = value;
        } else {
            revert("unknown parameter");
        }

        emit File(what, rate, value);
    }

    /// @notice increases the debt of a loan by a currencyAmount
    /// a change of the loan debt updates the rate debt and total debt
    /// @param loan the id of the loan
    /// @param currencyAmount the amount of currency to be added to the loan debt
    function incDebt(uint256 loan, uint256 currencyAmount) external auth {
        uint256 rate = loanRates[loan];
        require(block.timestamp == rates[rate].lastUpdated, "rate-group-not-updated");
        currencyAmount = safeAdd(currencyAmount, rmul(currencyAmount, rates[rate].fixedRate));
        uint256 pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = safeAdd(pie[loan], pieAmount);
        rates[rate].pie = safeAdd(rates[rate].pie, pieAmount);

        emit IncreaseDebt(loan, currencyAmount);
    }

    /// @notice decrease the loan's debt by a currencyAmount
    /// a change of the loan debt updates the rate debt and total debt
    /// @param loan the id of the loan
    /// @param currencyAmount the amount of currency to be removed from the loan debt
    function decDebt(uint256 loan, uint256 currencyAmount) external auth {
        uint256 rate = loanRates[loan];
        require(block.timestamp == rates[rate].lastUpdated, "rate-group-not-updated");
        uint256 pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = safeSub(pie[loan], pieAmount);
        rates[rate].pie = safeSub(rates[rate].pie, pieAmount);

        emit DecreaseDebt(loan, currencyAmount);
    }

    /// @notice returns the current debt based on actual block.timestamp (now)
    /// @param loan the id of the loan
    /// @return the debt of the loan
    function debt(uint256 loan) external view returns (uint256 debt) {
        uint256 rate_ = loanRates[loan];
        uint256 chi_ = rates[rate_].chi;
        if (block.timestamp >= rates[rate_].lastUpdated) {
            chi_ = chargeInterest(rates[rate_].chi, rates[rate_].ratePerSecond, rates[rate_].lastUpdated);
        }
        return toAmount(chi_, pie[loan]);
    }

    /// @notice returns the total debt of a interest rate group
    /// @param rate the id of the interest rate group
    /// @return the total debt of the interest rate group
    function rateDebt(uint256 rate) external view returns (uint256 totalDebt) {
        uint256 chi_ = rates[rate].chi;
        uint256 pie_ = rates[rate].pie;

        if (block.timestamp >= rates[rate].lastUpdated) {
            chi_ = chargeInterest(rates[rate].chi, rates[rate].ratePerSecond, rates[rate].lastUpdated);
        }
        return toAmount(chi_, pie_);
    }

    /// @notice set rate loanRates for a loan
    /// @param loan the id of the loan
    /// @param rate the id of the interest rate group
    function setRate(uint256 loan, uint256 rate) external auth {
        require(pie[loan] == 0, "non-zero-debt");
        // rate category has to be initiated
        require(rates[rate].chi != 0, "rate-group-not-set");
        loanRates[loan] = rate;
        emit SetRate(loan, rate);
    }

    /// @notice change rate loanRates for a loan
    /// @param loan the id of the loan
    /// @param newRate the id ofthe new interest rate group
    function changeRate(uint256 loan, uint256 newRate) external auth {
        require(rates[newRate].chi != 0, "rate-group-not-set");
        uint256 currentRate = loanRates[loan];
        drip(currentRate);
        drip(newRate);
        uint256 pie_ = pie[loan];
        uint256 debt_ = toAmount(rates[currentRate].chi, pie_);
        rates[currentRate].pie = safeSub(rates[currentRate].pie, pie_);
        pie[loan] = toPie(rates[newRate].chi, debt_);
        rates[newRate].pie = safeAdd(rates[newRate].pie, pie[loan]);
        loanRates[loan] = newRate;
        emit ChangeRate(loan, newRate);
    }

    /// @notice accrue needs to be called before any debt amounts are modified by an external component
    /// @param loan the id of the loan
    function accrue(uint256 loan) external {
        drip(loanRates[loan]);
    }

    /// @notice drip updates the chi of the rate category by compounding the interest
    /// @param rate the id of the interest rate group
    function drip(uint256 rate) public {
        if (block.timestamp >= rates[rate].lastUpdated) {
            (uint256 chi,) =
                compounding(rates[rate].chi, rates[rate].ratePerSecond, rates[rate].lastUpdated, rates[rate].pie);
            rates[rate].chi = chi;
            rates[rate].lastUpdated = uint48(block.timestamp);
        }
    }
}
