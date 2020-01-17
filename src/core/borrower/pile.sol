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
    // https://github.com/makerdao/dsr/blob/master/src/dsr.sol
    struct Rate {
        uint   pie;         // Total debt of all loans with this rate
        uint   chi;         // Accumulated rates
        uint   speed;       // Accumulation per second
        uint48 rho;         // Last time the rate was accumulated
    }

    mapping (uint => Rate) public rates;

    // loan => pie
    // pie = debt/chi
    mapping (uint => uint) public pie;
    // loan => rate
    mapping (uint => uint) public group;

    uint public total;

    constructor() public {
        wards[msg.sender] = 1;
        rates[0].chi      = ONE;
        rates[0].speed    = ONE;
    }

    // --- Public Debt Methods  ---
    // increase the loan's debt by wad
    function incDebt(uint loan, uint wad) public auth note {
        uint rate = group[loan];
        require(now <= rates[rate].rho);
        uint delta = toPie(rates[rate].chi, wad);
        pie[loan] = add(pie[loan], delta);
        rates[rate].pie = add(rates[rate].pie, delta);
        total = add(total, wad);
    }

    // decrease the loan's debt by wad
    function decDebt(uint loan, uint wad) public auth note {
        uint rate = group[loan];
        require(now <= rates[rate].rho);
        uint delta = toPie(rates[rate].chi, wad);
        pie[loan] = sub(pie[loan], delta);
        rates[rate].pie = sub(rates[rate].pie, delta);
        total = sub(total, wad);
    }

    function debt(uint loan) public view returns (uint) {
        uint rate = group[loan];
        uint chi = rates[rate].chi;
        if (now >= rates[rate].rho) {
            chi = updateChi(rates[rate].chi, rates[rate].speed, rates[rate].rho);
        }
        return toAmount(chi, pie[loan]);
    }

    function rateDebt(uint rate) public view returns (uint) {
        uint chi = rates[rate].chi;
        uint pie = rates[rate].pie;
        
        if (now >= rates[rate].rho) {
            chi = updateChi(rates[rate].chi, rates[rate].speed, rates[rate].rho);
        } 
        return toAmount(chi, pie);
    } 

    // --- Interest Rate Group Implementation ---

    // set rate group for a loan
    function setRate(uint loan, uint rate) public auth {
        require(pie[loan] == 0, "non-zero-debt");
        group[loan] = rate;
    }

    // change rate group for a loan
    function changeRate(uint loan, uint newRate) public auth {
        uint currentRate = group[loan];
        drip(currentRate);
        drip(newRate);
        uint pie_ = pie[loan];
        uint debt = toAmount(rates[currentRate].chi, pie_);
        rates[currentRate].pie = sub(rates[currentRate].pie, pie_);
        pie[loan] = toPie(rates[newRate].chi, debt);
        rates[newRate].pie = add(rates[newRate].pie, pie[loan]);
        group[loan] = newRate;
    }

    // set/change the interest rate of a rate category
    function file(uint rate, uint speed_) public auth {
        require(speed_ != 0);

        if (rates[rate].chi == 0) { 
            rates[rate].chi = ONE;
            rates[rate].rho = uint48(now);
        } else { 
            drip(rate);
        }
        rates[rate].speed = speed_; 
    }

    // accrue neeeds to be called before any debt amounts are modified by an external component
    function accrue(uint loan) public {
        drip(group[loan]);
    }
    
    // drip updates the chi of the rate category by compounding the interest and
    // updates the total debt
    function drip(uint rate) public {
        if (now >= rates[rate].rho) {
            (uint chi, uint delta) = compounding(rates[rate].chi, rates[rate].speed, rates[rate].rho, rates[rate].pie);
            rates[rate].chi = chi;
            rates[rate].rho = uint48(now);
            total = add(total, delta);
        }
    }
}