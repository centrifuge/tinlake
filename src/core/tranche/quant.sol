// Copyright (C) 2019 Centrifuge
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

// Quant
// Keeps track of the tranche debt. Manages iBorrow & its calculation.
contract Quant is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    struct Fee {
        uint chi;
        uint speed; // Accumulation per second
        uint48 rho; // Last time the rate was accumulated
    }
    
    Fee public iBorrow;
    uint public debt;
    
    constructor() public {
        wards[msg.sender] = 1;
        iBorrow.chi = ONE;
        iBorrow.speed = ONE;
    }

    function file(bytes32 what, uint speed_) public note auth {
         if (what == "iborrow") {
            drip();
            iBorrow.speed = speed_;
        }
    }

    function getSpeed() public returns(uint) {
        return iBorrow.speed;
    }

    function UpdateIBorrow(uint supplySpeed, uint reserve) public note auth {
        require (supplySpeed > 0);
        if (now >= iBorrow.rho) {
            drip();
        }
        uint supplySpeed_ = sub(supplySpeed, ONE);
        uint ratio = rdiv(add(reserve, debt), debt); 
        iBorrow.speed = add(rmul(ratio, supplySpeed_), ONE);
    }

    function drip() public note auth{
        if (now >= iBorrow.rho) {
            (uint latest, , uint wad) = compounding();
            iBorrow.chi = latest;
            iBorrow.rho = uint48(now);
            debt = add(debt, wad);   
        }
    }

    function updateDebt(int wad) public note auth  {
        if (now >= iBorrow.rho) {
            drip();
        }
        debt = uint(int(debt) + int(wad));
    }

    function compounding() internal view returns (uint, uint, uint) {
        uint48 rho = iBorrow.rho;
        require(now >= rho);
        uint speed = iBorrow.speed;

        uint chi = iBorrow.chi;

        // compounding in seconds
        uint latest = rmul(rpow(speed, now - rho, ONE), chi);
        uint chi_ = rdiv(latest, chi);
        uint wad = rmul(debt, chi_) - debt;
        return (latest, chi_, wad);
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
}
