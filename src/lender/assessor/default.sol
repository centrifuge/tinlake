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

pragma solidity >=0.5.12;

import "./base.sol";
import "tinlake-math/interest.sol";


// DefaultAssessor only charges interest based on the debt of the senior tranche
// The senior tranche only gets interest if its currency is used for loans.
contract DefaultAssessor is BaseAssessor, Interest {

    constructor(uint tokenAmountForONE) BaseAssessor(tokenAmountForONE) public {}

    // accrueTrancheInterest can implement different interest models
    function accrueTrancheInterest(address tranche_) public returns (uint) {
        SeniorTrancheLike tranche = SeniorTrancheLike(tranche_);

        if(tranche_ == junior) {
            return 0;

        }

        uint debt = safeAdd(tranche.borrowed(), tranche.interest());
        // move to tinlake-math
        // interest is calculated based on tranche debt

        return safeSub(chargeInterest(debt, tranche.ratePerSecond() , tranche.lastUpdated()), debt);

    }
}