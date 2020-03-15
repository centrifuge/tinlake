// Copyright (C) 2018  Rain <rainbreak@riseup.net>, Centrifuge
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

pragma solidity >=0.5.3;

import "ds-note/note.sol";
import "tinlake-math/interest.sol";
import "tinlake-auth/auth.sol";

// ## Interest Group based Pile
// The following is one implementation of a debt module. It keeps track of different buckets of interest rates and is optimized for many loans per interest bucket. It keeps track of interest
// rate accumulators (chi values) for all interest rate categories. It calculates debt each
// loan according to its interest rate category and pie value.
contract Pile is DSNote, Auth, Interest {
    // --- Data ---
    
    /// stores all needed information of an interest rate group
    struct Rate {
        uint   pie;                 // Total debt of all loans with this rate
        uint   chi;                 // Accumulated rates
        uint   ratePerSecond;       // Accumulation per second
        uint48 lastUpdated;         // Last time the rate was accumulated
    }

    /// Interest Rate Groups are identified by a `uint` and stored in a mapping
    mapping (uint => Rate) public rates;

    /// mapping of all loan debts
    /// the debt is stored as pie
    /// pie is defined as pie = debt/chi therefore debt = pie * chi
    /// where chi is the accumulated interest rate index over time
    mapping (uint => uint) public pie;
    /// loan => rate
    mapping (uint => uint) public loanRates;


    /// total debt of all ongoing loans
    uint public total;

    constructor() public {
        wards[msg.sender] = 1;
        /// pre-definition for loans without interest rates
        rates[0].chi = ONE;
        rates[0].ratePerSecond = ONE;
    }

     // --- Public Debt Methods  --- 
    /// increases the debt of a loan by a currencyAmount
    /// a change of the loan debt updates the rate debt and total debt
    function incDebt(uint loan, uint currencyAmount) external auth note {
        uint rate = loanRates[loan];
        require(now <= rates[rate].lastUpdated, "rate-group-not-updated");
        uint pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = safeAdd(pie[loan], pieAmount);
        rates[rate].pie = safeAdd(rates[rate].pie, pieAmount);
        total = safeAdd(total, currencyAmount);
    }

    /// decrease the loan's debt by a currencyAmount
    /// a change of the loan debt updates the rate debt and total debt
    function decDebt(uint loan, uint currencyAmount) external auth note {
        uint rate = loanRates[loan];
        require(now <= rates[rate].lastUpdated, "rate-group-not-updated");
        uint pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = safeSub(pie[loan], pieAmount);
        rates[rate].pie = safeSub(rates[rate].pie, pieAmount);
        total = safeSub(total, currencyAmount);
    }

    /// returns the current debt based on actual block.timestamp (now)
    function debt(uint loan) external view returns (uint) {
        uint rate_ = loanRates[loan];
        uint chi_ = rates[rate_].chi;
        if (now >= rates[rate_].lastUpdated) {
            chi_ = chargeInterest(rates[rate_].chi, rates[rate_].ratePerSecond, rates[rate_].lastUpdated);
        }
        return toAmount(chi_, pie[loan]);
    }

    /// returns the total debt of a interest rate group
    function rateDebt(uint rate) external view returns (uint) {
        uint chi_ = rates[rate].chi;
        uint pie_ = rates[rate].pie;

        if (now >= rates[rate].lastUpdated) {
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
    }

    // change rate loanRates for a loan
    function changeRate(uint loan, uint newRate) external auth note {
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
    }

    // set/change the interest rate of a rate category
    function file(uint rate, uint ratePerSecond) external auth note {
        require(ratePerSecond != 0, "rate-per-second-can-not-be-0");

        if (rates[rate].chi == 0) {
            rates[rate].chi = ONE;
            rates[rate].lastUpdated = uint48(now);
        } else { 
            drip(rate);
        }
        rates[rate].ratePerSecond = ratePerSecond;
    }

    // accrue needs to be called before any debt amounts are modified by an external component
    function accrue(uint loan) external {
        drip(loanRates[loan]);
    }
    
    // drip updates the chi of the rate category by compounding the interest and
    // updates the total debt
    function drip(uint rate) public {
        if (now >= rates[rate].lastUpdated) {
            (uint chi, uint deltaInterest) = compounding(rates[rate].chi, rates[rate].ratePerSecond, rates[rate].lastUpdated, rates[rate].pie);
            rates[rate].chi = chi;
            rates[rate].lastUpdated = uint48(now);
            total = safeAdd(total, deltaInterest);
        }
    }
}
