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

pragma solidity >=0.5.12;

import "ds-note/note.sol";
import "tinlake-math/interest.sol";
import "tinlake-auth/auth.sol";

// ## Interest Group based Pile
// The following is one implementation of a debt module. It keeps track of different buckets of interest rates and is optimized for many loans per interest bucket. It keeps track of interest
// rate accumulators (chi values) for all interest rate categories. It calculates debt each
// loan according to its interest rate category and pie value.
contract Pile is DSNote, Auth, Interest {
    // --- Data ---
    struct Rate {
        uint   pie;                 // Total debt of all loans with this rate
        uint   chi;                 // Accumulated rates
        uint   ratePerSecond;       // Accumulation per second
        uint48 lastUpdated;         // Last time the rate was accumulated
    }

    mapping (uint => Rate) public rates;

    // loan => pie
    // pie = debt/chi
    mapping (uint => uint) public pie;
    // loan => rate
    mapping (uint => uint) public loanRates;

    uint public total;

    constructor() public {
        wards[msg.sender] = 1;
        rates[0].chi = ONE;
        rates[0].ratePerSecond = ONE;
    }

    // --- Public Debt Methods  ---
    // increase the loan's debt by currencyAmount
    function incDebt(uint loan, uint currencyAmount) public auth note {
        uint rate = loanRates[loan];
        require(now <= rates[rate].lastUpdated);
        uint pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = add(pie[loan], pieAmount);
        rates[rate].pie = add(rates[rate].pie, pieAmount);
        total = add(total, currencyAmount);
    }

    // decrease the loan's debt by currencyAmount
    function decDebt(uint loan, uint currencyAmount) public auth note {
        uint rate = loanRates[loan];
        require(now <= rates[rate].lastUpdated);
        uint pieAmount = toPie(rates[rate].chi, currencyAmount);

        pie[loan] = sub(pie[loan], pieAmount);
        rates[rate].pie = sub(rates[rate].pie, pieAmount);
        total = sub(total, currencyAmount);
    }

    function debt(uint loan) public view returns (uint) {
        uint rate_ = loanRates[loan];
        uint chi_ = rates[rate_].chi;
        if (now >= rates[rate_].lastUpdated) {
            chi_ = updateChi(rates[rate_].chi, rates[rate_].ratePerSecond, rates[rate_].lastUpdated);
        }
        return toAmount(chi_, pie[loan]);
    }

    function rateDebt(uint rate) public view returns (uint) {
        uint chi_ = rates[rate].chi;
        uint pie_ = rates[rate].pie;

        if (now >= rates[rate].lastUpdated) {
            chi_ = updateChi(rates[rate].chi, rates[rate].ratePerSecond, rates[rate].lastUpdated);
        } 
        return toAmount(chi_, pie_);
    } 

    // --- Interest Rate Group Implementation ---

    // set rate loanRates for a loan
    function setRate(uint loan, uint rate) public auth {
        require(pie[loan] == 0, "non-zero-debt");
        loanRates[loan] = rate;
    }

    // change rate loanRates for a loan
    function changeRate(uint loan, uint newRate) public auth {
        uint currentRate = loanRates[loan];
        drip(currentRate);
        drip(newRate);
        uint pie_ = pie[loan];
        uint debt_ = toAmount(rates[currentRate].chi, pie_);
        rates[currentRate].pie = sub(rates[currentRate].pie, pie_);
        pie[loan] = toPie(rates[newRate].chi, debt_);
        rates[newRate].pie = add(rates[newRate].pie, pie[loan]);
        loanRates[loan] = newRate;
    }

    // set/change the interest rate of a rate category
    function file(uint rate, uint ratePerSecond) public auth {
        require(ratePerSecond != 0);

        if (rates[rate].chi == 0) {
            rates[rate].chi = ONE;
            rates[rate].lastUpdated = uint48(now);
        } else { 
            drip(rate);
        }
        rates[rate].ratePerSecond = ratePerSecond;
    }

    // accrue needs to be called before any debt amounts are modified by an external component
    function accrue(uint loan) public {
        drip(loanRates[loan]);
    }
    
    // drip updates the chi of the rate category by compounding the interest and
    // updates the total debt
    function drip(uint rate) public {
        if (now >= rates[rate].lastUpdated) {
            (uint chi, uint deltaInterest) = compounding(rates[rate].chi, rates[rate].ratePerSecond, rates[rate].lastUpdated, rates[rate].pie);
            rates[rate].chi = chi;
            rates[rate].lastUpdated = uint48(now);
            total = add(total, deltaInterest);
        }
    }
}