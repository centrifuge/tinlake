// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2018  Rain <rainbreak@riseup.net>, Centrifuge
pragma solidity >=0.6.12;

import "tinlake-math/interest.sol";
import "tinlake-auth/auth.sol";

// ## Interest Group based Pile
// The following is one implementation of a debt module. It keeps track of different buckets of interest rates and is optimized for many loans per interest bucket. It keeps track of interest
// rate accumulators (chi values) for all interest rate categories. It calculates debt each
// loan according to its interest rate category and pie value.
contract Pile is Auth, Interest {
    
    // --- Data ---

    // stores all needed information of an interest rate group
    struct Rate {
        uint   pie;                 // Total debt of all loans with this rate
        uint   chi;                 // Accumulated rates
        uint   ratePerSecond;       // Accumulation per second
        uint48 lastUpdated;         // Last time the rate was accumulated
        uint   fixedRate;           // fixed rate applied to each loan of the group
    }

    // Interest Rate Groups are identified by a `uint` and stored in a mapping
    mapping (uint => Rate) public rates;

    // mapping of all loan debts
    // the debt is stored as pie
    // pie is defined as pie = debt/chi therefore debt = pie * chi
    // where chi is the accumulated interest rate index over time
    mapping (uint => uint) public pie;
    // loan => rate
    mapping (uint => uint) public loanRates;


    // total debt of all ongoing loans
    uint public total;

    // Events
    event IncreaseDebt(uint indexed loan, uint currencyAmount);
    event DecreaseDebt(uint indexed loan, uint currencyAmount);
    event SetRate(uint indexed loan, uint rate);
    event ChangeRate(uint indexed loan, uint newRate);
    event File(bytes32 indexed what, uint rate, uint value);

    constructor() public {
        wards[msg.sender] = 1;
        // pre-definition for loans without interest rates
        rates[0].chi = ONE;
        rates[0].ratePerSecond = ONE;
    }

     // --- Public Debt Methods  ---
    // increases the debt of a loan by a currencyAmount
    // a change of the loan debt updates the rate debt and total debt
    function incDebt(uint loan, uint currencyAmount) external auth { 
        uint rate = loanRates[loan];
        require(block.timestamp == rates[rate].lastUpdated, "rate-group-not-updated");
        currencyAmount = safeAdd(currencyAmount, rmul(currencyAmount, rates[rate].fixedRate));
        uint pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = safeAdd(pie[loan], pieAmount);
        rates[rate].pie = safeAdd(rates[rate].pie, pieAmount);
        total = safeAdd(total, currencyAmount);

        emit IncreaseDebt(loan, currencyAmount);
    }

    // decrease the loan's debt by a currencyAmount
    // a change of the loan debt updates the rate debt and total debt
    function decDebt(uint loan, uint currencyAmount) external auth {
        uint rate = loanRates[loan];
        require(block.timestamp == rates[rate].lastUpdated, "rate-group-not-updated");
        uint pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = safeSub(pie[loan], pieAmount);
        rates[rate].pie = safeSub(rates[rate].pie, pieAmount);

        if (currencyAmount > total) {
            total = 0;
            return;
        }

        total = safeSub(total, currencyAmount);

        emit DecreaseDebt(loan, currencyAmount);
    }

    // returns the current debt based on actual block.timestamp (now)
    function debt(uint loan) external view returns (uint) {
        uint rate_ = loanRates[loan];
        uint chi_ = rates[rate_].chi;
        if (block.timestamp >= rates[rate_].lastUpdated) {
            chi_ = chargeInterest(rates[rate_].chi, rates[rate_].ratePerSecond, rates[rate_].lastUpdated);
        }
        return toAmount(chi_, pie[loan]);
    }

    // returns the total debt of a interest rate group
    function rateDebt(uint rate) external view returns (uint) {
        uint chi_ = rates[rate].chi;
        uint pie_ = rates[rate].pie;

        if (block.timestamp >= rates[rate].lastUpdated) {
            chi_ = chargeInterest(rates[rate].chi, rates[rate].ratePerSecond, rates[rate].lastUpdated);
        }
        return toAmount(chi_, pie_);
    }

    // --- Interest Rate Group Implementation ---

    // set rate loanRates for a loan
    function setRate(uint loan, uint rate) external auth {
        require(pie[loan] == 0, "non-zero-debt");
        // rate category has to be initiated
        require(rates[rate].chi != 0, "rate-group-not-set");
        loanRates[loan] = rate;
        emit SetRate(loan, rate);
    }

    // change rate loanRates for a loan
    function changeRate(uint loan, uint newRate) external auth {
        require(rates[newRate].chi != 0, "rate-group-not-set");
        uint currentRate = loanRates[loan];
        drip(currentRate);
        drip(newRate);
        uint pie_ = pie[loan];
        uint debt_ = toAmount(rates[currentRate].chi, pie_);
        rates[currentRate].pie = safeSub(rates[currentRate].pie, pie_);
        pie[loan] = toPie(rates[newRate].chi, debt_);
        rates[newRate].pie = safeAdd(rates[newRate].pie, pie[loan]);
        loanRates[loan] = newRate;
        emit ChangeRate(loan, newRate);
    }

    // set/change the interest rate of a rate category
    function file(bytes32 what, uint rate, uint value) external auth {
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
        } else revert("unknown parameter");

        emit File(what, rate, value);
    }

    // accrue needs to be called before any debt amounts are modified by an external component
    function accrue(uint loan) external {
        drip(loanRates[loan]);
    }

    // drip updates the chi of the rate category by compounding the interest and
    // updates the total debt
    function drip(uint rate) public {        
        if (block.timestamp >= rates[rate].lastUpdated) {
            (uint chi, uint deltaInterest) = compounding(rates[rate].chi, rates[rate].ratePerSecond, rates[rate].lastUpdated, rates[rate].pie);
            rates[rate].chi = chi;
            rates[rate].lastUpdated = uint48(block.timestamp);
            total = safeAdd(total, deltaInterest);
        }
    }
}
