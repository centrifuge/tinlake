// appraiser.sol -- sample contract to provide a price for assets
// Copyright (C) 2019 lucasvo

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

import "ds-test/test.sol";

contract OperatorLike {
    function balance() public returns(uint);
    function debt() public returns(uint);
}

contract TrancheManagerLike {
    function trancheCount() public returns(uint);
    function isEquity(address) public returns(bool);
    function poolValue() public returns(uint);
    function indexOf(address) public returns(int);
    function operatorOf(uint) public returns(address);
}

contract Assessor is DSTest {
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
         emit log_named_uint("trancheDebt", trancheDebt);
         uint trancheReserve = operator.balance();
         emit log_named_uint("trancheReserve", trancheReserve);
         int trancheIndex = trancheManager.indexOf(operator_);
         require(trancheIndex >= 0);
         
         emit log_named_int("trancheIndex", trancheIndex);
         // total debt of all tranches with lower risk
         uint totalSeniorDebt = calcSeniorDebt(trancheIndex-1);
         emit log_named_uint("totalSeniorDebt", totalSeniorDebt);
         // total assets in the reserves of all tranches with higher risk
         uint totalEquityReserve = calcEquityReserve(uint(trancheIndex+1));
         emit log_named_uint("totalEquityReserve", totalEquityReserve);
         uint poolValue = trancheManager.poolValue();

         if (trancheManager.isEquity(operator_)) {
            return calcEquityAssetValue(poolValue, trancheReserve, totalSeniorDebt);
         } 
         return calcSeniorAssetValue(poolValue, trancheReserve, trancheDebt, totalEquityReserve, totalSeniorDebt);
    }

    // Tranche.assets (Equity) = (Pool.value + Tranche.reserve - Sum(Senior.debt)) > 0 && (Pool.value - Tranche.reserve - Sum(Senior.debt)) || 0
    function calcEquityAssetValue(uint poolValue, uint trancheReserve, uint totalSeniorDebt) internal returns (uint) {
        int assetValue = int(poolValue + trancheReserve - totalSeniorDebt);
        return (assetValue > 0) ? uint(assetValue) : 0;
    }

    // Tranche.assets (Senior) = (Tranche.debt < (Pool.value + Sum(Equity.reserve))) && (Sum(Senior.debt) + Tranche.reserve) || (Pool.value + Sum(Equity.reserve) + Tranche.reserve)
    function calcSeniorAssetValue(uint poolValue, uint trancheReserve, uint trancheDebt, uint equityReserve, uint seniorDebt) internal returns (uint) {
         // healthy: outstanding loans and / or reserves of tranches with higher risk can cover the tranche debt
         if ((poolValue + equityReserve - seniorDebt ) >= trancheDebt) {
            return trancheDebt + trancheReserve;
         } 
         // losses: tranche debt can not be covered anymore.
         // Tranche assets contain everything left in the loan pool + reserves of tranches with higher risk minus the outstanding debt of tranches with lower risk 
         int assetValue = int(poolValue + equityReserve + trancheReserve - seniorDebt);
         return (assetValue > 0) ? uint(assetValue) : 0;
    }

    // totalEquityReserve = sum of the reserves of all tranches with higher risk than the tranche with the index provided
    function calcEquityReserve(uint startIndex) internal returns (uint) {
        uint totalEquityReserve = 0;
        for (uint i = startIndex; i < trancheManager.trancheCount(); i++) {
            OperatorLike equityOperator = OperatorLike(trancheManager.operatorOf(i));
            totalEquityReserve += equityOperator.balance();
        }
        return totalEquityReserve;
    }

    // totalSeniorDebt = sum of the debt of all tranches with lower risk than the tranche with the index provided
    function calcSeniorDebt(int startIndex) internal returns (uint) {
        uint totalSeniorDebt = 0;
        emit log_named_int("start", startIndex);
        for (int i = startIndex; i >= 0; i--) {
            OperatorLike seniorOperator = OperatorLike(trancheManager.operatorOf(uint(i)));
            emit log_named_uint("debt", seniorOperator.debt());
            totalSeniorDebt += seniorOperator.debt();
            emit log_named_uint("totalSeniorDebt", totalSeniorDebt);
        }
        emit log_named_uint("totalSeniorDebt", totalSeniorDebt);
        return totalSeniorDebt;
    }
}
