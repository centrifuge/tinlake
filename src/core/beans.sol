// Copyright (C) 2018  Rain <rainbreak@riseup.net>, lucasvo
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

// Beans
// Keeps track of interest rate accumulators (chi values) for all interest rate categories.
// Calculates debt each loan according to its interest rate category and pie value.
contract Beans is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }
    
    // --- Data ---
    // https://github.com/makerdao/dsr/blob/master/src/dsr.sol
    struct Fee {
        uint debt;
        uint chi;
        uint speed; // Accumulation per second
        uint48 rho; // Last time the rate was accumulated
    }

    mapping (uint => Fee) public fees;
    mapping (uint => uint) public pie;

    uint public totalDebt;

    constructor() public {
        wards[msg.sender] = 1;
        fees[0].chi = ONE;
        fees[0].speed = ONE;
    }

    function file(uint fee, uint speed_) public auth note {
        require(speed_ != 0);
        fees[fee].speed = speed_;
        fees[fee].chi = ONE;
        fees[fee].rho = uint48(now);
        drip(fee);
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

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, y) / ONE;
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

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, ONE), y / 2) / y;
    }

    function div(uint x, uint y) internal pure returns (uint z) {
        z = x / y;
    }

    function incLoanDebt(uint loan, uint fee, uint wad) public auth note {
        require(now == fees[fee].rho);
        pie[loan] = add(pie[loan], calcPie(fees[fee].chi, wad));
        incTotalDebt(fee, wad);
    }

    function decLoanDebt(uint loan, uint fee, uint wad) public auth note {
        require(now == fees[fee].rho);
        pie[loan] = sub(pie[loan], calcPie(fees[fee].chi, wad));
        decTotalDebt(fee, wad);
    }

    function compounding(uint fee) public view returns (uint, uint, uint) {
        uint48 rho = fees[fee].rho;
        require(now >= rho);
        uint speed = fees[fee].speed;

        uint chi = fees[fee].chi;
        uint debt_ = fees[fee].debt;

        // compounding in seconds
        uint latest = rmul(rpow(speed, now - rho, ONE), chi);
        uint chi_ = rdiv(latest, chi);
        uint wad = rmul(debt_, chi_) - debt_;
        return (latest, chi_, wad);
    }

    // --- Fee Accumulation ---
    function drip(uint fee) public {
        if (now >= fees[fee].rho) {
            (uint latest, , uint wad) = compounding(fee);
            fees[fee].chi = latest;
            fees[fee].rho = uint48(now);
            incTotalDebt(fee, wad);   
        }
    }

    function burden(uint loan, uint fee) public view returns (uint) {
        uint chi = fees[fee].chi;
        if (now >= fees[fee].rho) {
            (chi, ,) = compounding(fee);
        }
        return calcDebt(chi, pie[loan]);
    }

    function debtOf(uint loan, uint fee) public view returns(uint) {
        return calcDebt(fees[fee].chi, pie[loan]);
    }
    
    function incTotalDebt(uint fee, uint wad) private {
        fees[fee].debt = add(fees[fee].debt, wad);
        totalDebt = add(totalDebt, wad);
    }

    function decTotalDebt(uint fee, uint wad) private {
        fees[fee].debt = sub(fees[fee].debt, wad);
        totalDebt = sub(totalDebt, wad);
    }

    function calcPie(uint chi, uint wad) private view returns (uint) {
        return rdiv(wad, chi);
    }

    function calcDebt(uint chi, uint pie_) private view returns (uint) {
        return rmul(pie_, chi);
    }

}