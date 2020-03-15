// Copyright (C) 2020 Centrifuge

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
import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

contract TrancheLike {
    function balance() public view returns(uint);
    function tokenSupply() public view returns(uint);
}

contract SeniorTrancheLike {
    function drip() public;
    function debt() public view returns(uint);
    function interest() public view returns(uint);
    function borrowed() public view returns(uint);
    function balance() public view returns(uint);

    function ratePerSecond() public view returns(uint);
    function lastUpdated() public view returns(uint);
}


contract PileLike {
    function debt() public returns(uint);
}

contract PoolLike {
    function totalValue() public view returns(uint);
}

// Base contract for assessor contracts
contract BaseAssessor is Math, Auth {
    // --- Tranches ---
    address public senior;
    address public junior;

    PoolLike public pool;

    // amounts of token for a token price of ONE
    // constant factor multiplied with the token price
    uint public tokenAmountForONE;

    // denominated in RAD
    // ONE == 100%
    // only needed for two tranches. if only one tranche is used == 0
    uint public minJuniorRatio;

    // --- Assessor ---
    // computes the current asset value for tranches.
    constructor(uint tokenAmountForONE_) public {
        wards[msg.sender] = 1;
        // only set once in the constructor
        // not allowed to change in an ongoing deployment
        tokenAmountForONE = tokenAmountForONE_;
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr_) public auth {
        if (contractName == "junior") { junior = addr_; }
        else if (contractName == "senior") { senior = addr_; }
        else if (contractName == "pool") { pool = PoolLike(addr_); }
        else revert();
    }

    function file(bytes32 what, uint value) public auth {
        if (what == "minJuniorRatio") { minJuniorRatio = value; }
        else revert();
    }

    function calcAssetValue(address tranche) public view returns(uint) {
        require(tranche  == junior || tranche == senior);
        uint trancheReserve = TrancheLike(tranche).balance();
        uint poolValue = pool.totalValue();
        if (tranche == junior) {
            return _calcJuniorAssetValue(poolValue, trancheReserve, _seniorDebt());
        }
        return _calcSeniorAssetValue(poolValue, trancheReserve, _seniorDebt(), _juniorReserve());
    }

    function calcTokenPrice(address tranche) public view returns (uint) {
        require(tranche  == junior || tranche == senior);
        return safeMul(_calcTokenPrice(tranche), tokenAmountForONE);
    }
    
    function calcAndUpdateTokenPrice(address tranche) public returns (uint) {
        _drip();
        return calcTokenPrice(tranche);
    }

    /// ensures latest senior debt and updates the state with the debt
    function _drip() internal {
        if (senior != address(0x0)) {
            SeniorTrancheLike(senior).drip();
        }
    }

    function _calcTokenPrice(address tranche) internal view returns (uint) {
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

    function _calcJuniorAssetValue(uint poolValue, uint juniorReserve, uint seniorDebt) internal pure returns (uint) {
        // available for junior
        uint available = safeAdd(poolValue, juniorReserve);

        // senior debt needs to be covered first
        if (available > seniorDebt) {
            return safeSub(available, seniorDebt);
        }
        // currently junior would receive nothing
        return 0;
    }

   function _calcSeniorAssetValue(uint poolValue, uint seniorReserve, uint seniorDebt, uint juniorReserve) internal pure returns (uint) {
        // available to cover senior debt
        uint available = safeAdd(poolValue, juniorReserve);
        if (available >= seniorDebt) {
            // currently no losses for senior
            return safeAdd(seniorDebt, seniorReserve);
        }
        // currently senior would have losses (means junior lost everything)
        // therefore senior would receive the entire pool
        return safeAdd(available, seniorReserve);
   }

    function _juniorReserve() internal view returns (uint) {
        return TrancheLike(junior).balance();
    }

    function _seniorDebt() internal view returns (uint) {
        return (senior != address(0x0)) ? SeniorTrancheLike(senior).debt() : 0;
    }

    /// returns the maximum allowed seniorAssetValue to fulfill the minJuniorRatio
    /// with the current juniorAssetValue.
    /// @return maximum allowed seniorAssetValue
    /// @dev return value is denominated in WAD(10^18)
    function calcMaxSeniorAssetValue() public view returns (uint) {
        uint juniorAssetValue = calcAssetValue(junior);
        if (juniorAssetValue == 0) {
            return 0;
        }
        return safeSub(rdiv(juniorAssetValue, minJuniorRatio), juniorAssetValue);
    }

    /// returns the minimum required juniorAssetValue to fulfill the minJuniorRatio
    /// with the current seniorAssetValue
    /// @return minimum junior asset value
    /// @dev return value is denominated in WAD(10^18)
    function calcMinJuniorAssetValue() public view returns (uint) {
        if (senior == address(0)) {
            return 0;
        }
        uint seniorAssetValue = calcAssetValue(senior);
        if (seniorAssetValue == 0) {
            return 0;
        }
        return rmul(rdiv(seniorAssetValue, ONE-minJuniorRatio), minJuniorRatio);
    }

    /// returns the current juniorRatio
    /// the current juniorRatio can be below the minJuniorRatio because of loan defaults
    function currentJuniorRatio() public view returns(uint) {
        if (senior == address(0)) {
            return ONE;
        }
        uint juniorAssetValue = calcAssetValue(junior);
        return rdiv(juniorAssetValue, safeAdd(juniorAssetValue, calcAssetValue(senior)));
    }

    /// supplying more currency in the senior tranche can break the required minJuniorRatio
    /// the method check if an additional supply would break the ratio
    /// @return bool flag if supply is approved
    function supplyApprove(address tranche, uint currencyAmount) public returns(bool) {
        // always allowed to supply into junior || minJuniorRatio feature not activated
        if (tranche == junior || minJuniorRatio == 0) {
            return true;
        }
        _drip();

        if (tranche == senior && safeAdd(calcAssetValue(senior), currencyAmount) <= calcMaxSeniorAssetValue()) {
            return true;
        }
        return false;
    }

    /// redeeming currency from the junior tranche can break the required minJuniorRatio
    /// the method check if an additional redeem would break the ratio
    /// @return bool flag if redeem is approved
    function redeemApprove(address tranche, uint currencyAmount) public returns(bool) {
        // always allowed to redeem into senior || minJuniorRatio feature not activated || only single tranche
        if (tranche == senior || minJuniorRatio == 0 || senior == address(0)) {
            return true;
        }

        _drip();

        if (tranche == junior && safeSub(calcAssetValue(junior), currencyAmount) >= calcMinJuniorAssetValue()) {
            return true;

        }
        return false;
    }
}
