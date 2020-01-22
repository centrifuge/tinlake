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

    // amounts of token for a token price of ONE
    // constant factor multiplied with the token price
    uint public tokenAmountForONE;

    // denominated in RAD
    // ONE == 100%
    uint public maxJuniorRatio;

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
        else if (what == "maxJuniorRatio") { maxJuniorRatio = value; }
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

    function calcTokenPrice(address tranche) public returns (uint) {
        return mul(_calcTokenPrice(tranche), tokenAmountForONE);
    }

    function _calcTokenPrice(address tranche) internal returns (uint) {
        uint tokenSupply = TrancheLike(tranche).tokenSupply();
        uint assetValue = calcAssetValue(tranche);
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


    function _calcMaxSeniorAssetValue(uint juniorAssetValue) internal returns (uint) {
        // maxJuniorRatio = 100/(maxSeniorAssetValue + juniorAssetValue)*juniorAssetValue
        // therefore
        // maxSeniorAssetValue = 100*juniorAssetValue/maxJuniorRatio - juniorAssetValue
        // 100% == ONE
        // maxSeniorAssetValue = ONE*juniorAssetValue/maxJuniorRatio - juniorAssetValue
        // maxSeniorAssetValue = juniorAssetValue/maxJuniorRatio - juniorAssetValue
        if (juniorAssetValue == 0) {
            return 0;
        }
        return rdiv(juniorAssetValue, maxJuniorRatio) - juniorAssetValue;
    }

    function calcMaxSeniorAssetValue() public returns (uint) {
       return  _calcMaxSeniorAssetValue(calcAssetValue((junior)));
    }

    // only needed for external contracts
    function currentJuniorRatio() public returns(uint) {
        // currentJuniorRatio = 100/(seniorAssetValue + juniorAssetValue)*juniorAssetValue
        uint juniorAssetValue = calcAssetValue(junior);
        return rmul(rdiv(ONE,(add(juniorAssetValue, calcAssetValue(senior)))), juniorAssetValue);
    }

    function supplyApprove(address tranche, uint currencyAmount) public returns(bool) {
        // always allowed to supply into junior || maxJuniorRatio feature not activated
        if (tranche == junior || maxJuniorRatio == 0) {
            return true;
        }

        if (tranche == senior) {
            uint maxSeniorAssetValue = _calcMaxSeniorAssetValue(calcAssetValue((junior)));
            uint seniorAssetValue = calcAssetValue(senior);

            if (maxSeniorAssetValue < seniorAssetValue) {
                return false;
            }
            if (currencyAmount <= sub(maxSeniorAssetValue, seniorAssetValue)) {
                return true;
            }
        }
        return false;
    }

    function redeemApprove(address tranche, uint currencyAmount) public returns(bool) {
        // always allowed to redeem into senior || maxJuniorRatio feature not activated
        if (tranche == senior || maxJuniorRatio == 0) {
            return true;
        }

        if (tranche == junior) {
            // calculate max senior with potential reduced junior
            uint maxPostSeniorAssetValue = _calcMaxSeniorAssetValue(sub(calcAssetValue(junior), currencyAmount));

            // if sub fails not enough curreny in the reserve
            uint reducedJuniorReserve = sub(_juniorReserve(), currencyAmount);

            uint postSeniorAssetValue = _calcSeniorAssetValue(pool.totalValue(), TrancheLike(senior).balance(), SeniorTrancheLike(senior).debt(), reducedJuniorReserve);

            if (postSeniorAssetValue <= maxPostSeniorAssetValue) {
                return true;
            }
        }
        return false;
    }
}
