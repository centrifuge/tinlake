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


pragma solidity >=0.4.24;

contract OperatorLike {
    function balance() public returns(uint);
    function debt() public returns(uint);
}

contract TrancheManagerLike {
    function trancheCount() public returns(uint);
    function isJunior(address) public returns(bool);
    function poolValue() public returns(uint);
    function indexOf(address) public returns(int);
    function juniorOperator() public returns(address);
    function seniorOperator() public returns(address);
}

contract Assessor {
    // --- Data ---
    TrancheManagerLike trancheManager; 

    // --- Assessor ---
    // computes the current asset value for tranches.
    constructor(address trancheManager_) public {
        trancheManager = TrancheManagerLike(trancheManager_);
    }

    function getAssetValueFor(address operator_) public returns (uint) {
         OperatorLike operator = OperatorLike(operator_);
         uint trancheDebt = operator.debt();
         uint trancheReserve = operator.balance();
         uint poolValue = trancheManager.poolValue();
         if (trancheManager.isJunior(operator_)) {
            uint seniorDebt = calcSeniorDebt(); 
            return calcJuniorAssetValue(poolValue, trancheReserve, seniorDebt);
         }

         uint juniorReserve = calcJuniorReserve();
         return calcSeniorAssetValue(poolValue, trancheReserve, trancheDebt, juniorReserve);   
    }

    // Tranche.assets (Junior) = (Pool.value + Tranche.reserve - Senior.debt) > 0 && (Pool.value - Tranche.reserve - Senior.debt) || 0
    function calcJuniorAssetValue(uint poolValue, uint trancheReserve, uint seniorDebt) internal returns (uint) {
        int assetValue = int(poolValue + trancheReserve - seniorDebt);
        return (assetValue > 0) ? uint(assetValue) : 0;
    }

    // Tranche.assets (Senior) = (Tranche.debt < (Pool.value + Junior.reserve)) && (Senior.debt + Tranche.reserve) || (Pool.value + Junior.reserve + Tranche.reserve)
    function calcSeniorAssetValue(uint poolValue, uint trancheReserve, uint trancheDebt, uint juniorReserve) internal returns (uint) {
        return ((poolValue + juniorReserve) >= trancheDebt) ? (trancheDebt + trancheReserve) : (poolValue + juniorReserve + trancheReserve);

    }

    function calcJuniorReserve() internal returns (uint) {
        uint juniorReserve =  (trancheManager.trancheCount() > 1) ? OperatorLike(trancheManager.juniorOperator()).balance() : 0;
        return juniorReserve;
    }

    function calcSeniorDebt() internal returns (uint) {
         uint seniorDebt =  (trancheManager.trancheCount() > 1) ? OperatorLike(trancheManager.seniorOperator()).debt() : 0;
        return seniorDebt;
    }
}