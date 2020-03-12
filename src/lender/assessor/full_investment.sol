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

pragma solidity >=0.5.3;

import "./base.sol";
import "tinlake-math/interest.sol";

// FullInvestmentAssessor charges interest on invested currency (+ optional existing interest) in the senior tranche.
// It doesn't matter if the currency of the senior tranche is used for loans.
contract FullInvestmentAssessor is BaseAssessor, Interest {

    constructor(uint tokenAmountForONE) BaseAssessor(tokenAmountForONE) public {}

    /// accrueTrancheInterest implements interest accumulation based total supplied tranche currency and existing interest amounts
    function accrueTrancheInterest(address tranche_) public view returns (uint) {
        SeniorTrancheLike tranche = SeniorTrancheLike(tranche_);

        if(tranche_ == junior) {
            return 0;

        }

        require(tranche_ == senior);

        uint interestBearingAmount = safeAdd(safeAdd(tranche.borrowed(), tranche.interest()), tranche.balance());

        return safeSub(chargeInterest(interestBearingAmount, tranche.ratePerSecond() , tranche.lastUpdated()), interestBearingAmount);
    }
}
