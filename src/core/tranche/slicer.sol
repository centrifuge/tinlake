// Copyright (C) 2019  Centrifuge
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

contract TrancheManagerLike {
   function getTrancheAssets(address) public returns(uint);
}

contract ReserveLike {
   function tokenSupply() public returns(uint);
}

// Slicer
// Calculates payouts and tranche slices represented in tokens
contract Slicer is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }
    
    // --- Data ---
    TrancheManagerLike public trancheManager;
    ReserveLike public reserve;

    constructor(address trancheManager_, address reserve_) public {
        reserve = ReserveLike(reserve_);
        trancheManager = TrancheManagerLike(trancheManager_);
        wards[msg.sender] = 1;
    }

    function getSlice(uint currencyAmount) public note auth returns (uint) {
        uint tokenPrice = getTokenPrice();
        return calcSlice(currencyAmount, tokenPrice);
    }

    function getPayout(uint tokenAmount) public note auth returns (uint) {
        uint tokenPrice = getTokenPrice();
        return calcPayout(tokenAmount, tokenPrice);
    }

    function getTokenPrice() public returns (uint) {
        uint totalSupply = reserve.tokenSupply();
        uint totalAssets = trancheManager.getTrancheAssets(address(this));
        return calcTokenPrice(totalSupply, totalAssets);
    }

    // tokenPrice in rad / precision: 10^27
    function calcPayout(uint tokenAmount, uint tokenPrice) internal pure returns (uint) {
        return rmul(tokenAmount, tokenPrice);
    }

    // tokenPrice in rad / precision: 10^27
    function calcSlice(uint currencyAmount, uint tokenPrice) internal pure returns (uint) {
        return rdiv(currencyAmount, tokenPrice);
    }

    // tokenSupply & totalAssets in wad / precision: 10^18 & tokenPrice in rad / precision: 10^27
    function calcTokenPrice(uint tokenSupply, uint totalAssets) internal pure returns (uint) {
        return rdiv(totalAssets, tokenSupply);
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
