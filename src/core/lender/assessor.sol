// Copyright (C) 2019 Centrifuge

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
import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

contract TrancheLike {
    function balance() public returns(uint);
    function tokenSupply() public returns(uint);
}
contract SeniorTrancheLike {
    function debt() public returns(uint);
}

contract PileLike {
    function debt() public returns(uint);
}

contract PoolLike {
    function totalValue() public returns(uint);
}

contract Assessor is Math, DSNote, Auth {
    // --- Tranches ---
    address public senior;
    address public junior;

    PoolLike public pool;

    // initial net asset value
    uint public initialNAV;

    // amounts of token for a token price of ONE
    // constant factor multiplied with the token price
    uint public tokenAmountForONE;

    // --- Assessor ---
    // computes the current asset value for tranches.
    constructor() public {
        wards[msg.sender] = 1;
        tokenAmountForONE = 1;
    }

    // --- Calls ---
    function depend(bytes32 what, address addr_) public auth {
        if (what == "junior") { junior = addr_; }
        else if (what == "senior") { senior = addr_; }
        else if (what == "pool") { pool = PoolLike(addr_); }
        else revert();
    }

    function file(bytes32 what, uint value) public auth {
        if (what == "tokenAmountForONE") { tokenAmountForONE = value; }
        else revert();
    }

    function calcAssetValue(address tranche) public returns(uint) {
        uint trancheReserve = TrancheLike(tranche).balance();
        uint poolValue = pool.totalValue();
        if (tranche == junior) {
            return _calcJuniorAssetValue(poolValue, trancheReserve, _seniorDebt());
        }
        return _calcSeniorAssetValue(poolValue, trancheReserve, SeniorTrancheLike(tranche).debt(), _juniorReserve());
    }

    function calcTokenPrice() public returns (uint) {
        return mul(_calcTokenPrice(), tokenAmountForONE);
    }

    function _calcTokenPrice() internal returns (uint) {
        uint tokenSupply = TrancheLike(msg.sender).tokenSupply();
        uint assetValue = calcAssetValue(msg.sender);
        if (tokenSupply == 0) {
            return ONE;
        }
        if (assetValue == 0) {
            revert("tranche is bankrupt");
        }
        return rdiv(assetValue, tokenSupply);
    }

    // Tranche.assets (Junior) = (Pool.value + Tranche.reserve - Senior.debt) > 0 && (Pool.value - Tranche.reserve - Senior.debt) || 0
    function _calcJuniorAssetValue(uint poolValue, uint trancheReserve, uint seniorDebt) internal returns (uint) {
        int assetValue = int(poolValue + trancheReserve - seniorDebt);
        return (assetValue > 0) ? uint(assetValue) : 0;
    }

    // Tranche.assets (Senior) = (Tranche.debt < (Pool.value + Junior.reserve)) && (Senior.debt + Tranche.reserve) || (Pool.value + Junior.reserve + Tranche.reserve)
    function _calcSeniorAssetValue(uint poolValue, uint trancheReserve, uint trancheDebt, uint juniorReserve) internal returns (uint) {
        return ((poolValue + juniorReserve) >= trancheDebt) ? (trancheDebt + trancheReserve) : (poolValue + juniorReserve + trancheReserve);
    }

    function _juniorReserve() internal returns (uint) {
        return TrancheLike(junior).balance();
    }

    function _seniorDebt() internal returns (uint) {
        return (senior != address(0x0)) ? SeniorTrancheLike(senior).debt() : 0;
    }
}