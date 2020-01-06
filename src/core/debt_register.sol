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

pragma solidity >=0.4.24;

import "ds-note/note.sol";


// ## DebtLike is the interface for any debt module.
contract DebtLike {
    uint public total;
    function debt(uint) public view returns (uint);
    function accrue(uint) public;
    function inc(uint, uint) public;
    function dec(uint, uint) public;
}

// ## Interst Group based DebtRegister
// The following is one implementation of a debt module. It keeps track of different buckets of interest rates and is optimized for many loans per interest bucket. It keeps track of interest
// rate accumulators (chi values) for all interest rate categories. It Calculates debt each
// loan according to its interest rate category and debtBalance value.
contract DebtRegister is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    // https://github.com/makerdao/dsr/blob/master/src/dsr.sol
    struct Rate {
        uint   pie;         // Total debt of all loans with this rate
        uint   chi;       // Accumulated rates
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

    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
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

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, ONE), y / 2) / y;
    }

    function div(uint x, uint y) internal pure returns (uint z) {
        z = x / y;
    }

    // --- Public Debt Methods  ---
    // increases the loan's debt by wad
    function increase(uint loan, uint wad) public auth note {
        uint rate = group[loan];
        require(now <= rates[rate].rho);
        uint delta = toPie(rates[rate].chi, wad);
        pie[loan] = add(pie[loan], delta);
        rates[rate].pie = add(rates[rate].pie, delta);
        total = add(total, wad);
    }

    // decreases the loan's debt by wad
    // TODO: this function has no tests
    function decrease(uint loan, uint wad) public auth note {
        uint rate = group[loan];
        require(now <= rates[rate].rho);
        uint delta = toPie(rates[rate].chi, wad);
        pie[loan] = sub(pie[loan], delta);
        rates[rate].pie = sub(rates[rate].pie, delta);
        total = sub(total, wad);
    }

    // accrue neeeds to be called before any debt amounts are modified by an external component
    function accrue(uint loan) public {
        drip(group[loan]);
    }

    // --- Interest Rate Group Implementation ---

    // changes the interest rate of a rate category
    function file(uint rate, uint speed_) public auth note {
        require(speed_ != 0);
        rates[rate].speed = speed_;
        rates[rate].chi = ONE;
        rates[rate].rho = uint48(now);
        drip(rate);
    }

    // Converters:
    // convert debt amount to pie
    function toPie(uint chi, uint pie) public view returns (uint) {
        return rdiv(pie, chi);
    }

    // convert pie to debt amount
    function fromPie(uint chi, uint pie) public view returns (uint) {
        return rmul(pie, chi);
    }

    // compound calculates the new chi, the delta between old and new chi and the delta of debt
    function compound(uint rate) public view returns (uint chi, uint delta) {
        uint48 rho = rates[rate].rho;
        // require(now >= rho); TODO: why do we need to check for this edge case?
        uint speed = rates[rate].speed;
        uint chi = rates[rate].chi;
        uint pie = rates[rate].pie;
        uint debt = fromPie(chi, pie);

        // compounding in seconds
        uint chi_ = rmul(rpow(speed, now - rho, ONE), chi);
        require(chi != 0);
        delta = fromPie(chi_, pie) - debt;

        return (chi_, delta);
    }

    // drip updates the chi of the rate category by compounding the interest and
    // updates the total debt
    function drip(uint rate) public {
        if (now >= rates[rate].rho) {
            (uint chi, uint delta) = compound(rate);
            rates[rate].chi = chi;
            rates[rate].rho = uint48(now);
            total = add(total, delta);
        }
    }


    function debt(uint loan) public view returns (uint) {
        uint rate = group[loan];
        uint chi = rates[rate].chi;
        if (now >= rates[rate].rho) {
            (chi,) = compound(rate);
        }
        return fromPie(chi, pie[loan]);
    }

    function set(uint loan, uint rate) public auth {
        require(pie[loan] == 0, "non-zero-debt");
        group[loan] = rate;
    }

    function change(uint loan, uint rate_) public auth {
        uint rate = group[loan];
        drip(rate);
        drip(rate_);
        uint pie_ = pie[loan];
        uint debt = fromPie(rates[rate].chi, pie_);
        rates[rate].pie = sub(rates[rate].pie, pie_);
        pie[loan] = toPie(rates[rate_].chi, debt);
        rates[rate_].pie = add(rates[rate_].pie, pie[loan]);
        // TODO decTotalDebt(currentRate, debt);
        // TODO incTotalDebt(newRate, debt);
    }
}
