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

contract OperatorLike {
    function balance() public returns(uint);
    function debt() public returns(uint);
}

contract TrancheManagerLike {
    function isSenior(address tranche) public returns(bool);
    function poolDebt() public returns(uint);
    function getTrancheDebt(address) public returns(uint);
    function getTrancheReserve(address) public returns(uint);
}

contract Assessor {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TrancheManagerLike trancheManager; 

    // --- Assessor ---
    // computes the current asset value of tranches. Senior Tranche is considered the first one in the array.
    constructor(address trancheManager_) public {
        wards[msg.sender] = 1;
        trancheManager = new TrancheManagerLike(trancheManager_);
    }

    function getAssetValueFor(address operator_) public returns (uint) {
        // get tranche Debt
        // get tranche reserve 
        // get poolDebt
        if (isSenior(operator_)) {
            return getSeniorAssetValue();
        }
        return getJuniorAssetValue(tranche_);
        // compute senior pure
        // compute junior pure 
        // write tests
        tranche = tranche_;
        return assetReturn;
    }

/*
    Senior.assets = (Senior.debt < (Tinlake.debt + Equity.reserve)) && (Senior.debt + Senior.reserve) || (Tinlake.debt + Equity.reserve + Senior.reserve)
    Equity.assets = (Tinlake.debt - Senior.debt + Equity.reserve) > 0 && (Tinlake.debt - Senior.debt + Equity.reserve) || 0
    */
    function getSeniorAssetValue() intrenal returns (uint) {
        (, OperatorLike operator)[] tranches = trancheManager.tranches();
        OperatorLike operator = 
        // senior debt
        uint seniorDebt = tranches[0].operator.debt();
        // pool Debt
        uint poolDebt = 
        // summe junior reserves
    }

    function getJuniorAssetValue(address Tranche) intrenal returns (uint) {
        // summer senior debt
        // summe all reserves below me
        // pool Debt  
    }

    function isSenior(address tranche_) public returns (bool) {
        (uint, OperatorLike)[] tranches = trancheManager.tranches();
        return (tranches[0] == tranche_);
    }


}
