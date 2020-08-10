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
pragma solidity >=0.5.15 <0.6.0;

import "./ticker.sol";
import "tinlake-auth/auth.sol";

interface EpochTrancheLike {
    function epochUpdate(uint epochID, uint supplyFulfillment_,
        uint redeemFulfillment_, uint tokenPrice_) external;
    function getTotalOrders(uint epochID) external returns(uint totalSupply, uint totalRedeem);
}

interface ReserveLike {
    function updateMaxCurrency(uint currencyAmount) external;
    function balance() external returns (uint);
}

interface AssessorLike {
    function calcSeniorTokenPrice(uint NAV_) external returns(uint);
    function calcJuniorTokenPrice(uint NAV_) external returns(uint);
    function maxReserve() external returns(uint);
    function calcNAV() external returns (uint);
    function seniorDebt() external returns(uint);
    function seniorBalance() external returns(uint);
}

contract EpochCoordinator is Ticker, Auth {
    EpochTrancheLike juniorTranche;
    EpochTrancheLike seniorTranche;

    ReserveLike reserve;
    AssessorLike assessor;

    uint public lastEpochExecuted;

    struct Order {
        uint  juniorRedeem;
        uint  juniorSupply;
        uint  seniorRedeem;
        uint  seniorSupply;
    }

    Order public bestSubmission;
    uint public  bestSubScore;
    Order public order;


    uint public epochSeniorTokenPrice;
    uint public epochJuniorTokenPrice;
    uint public epochNAV;
    uint public epochSeniorDebt;
    uint public epochSeniorBalance;

    bool public submissionPeriod;

    // challenge period end timestamp
    uint public challengePeriodEnd;

    uint public challengeTime;

    constructor() public {
        wards[msg.sender] = 1;
        challengeTime = 1 hours;
    }

    /// sets the dependency to another contract
    function depend (bytes32 contractName, address addr) public auth {
        if (contractName == "juniorTranche") { juniorTranche = EpochTrancheLike(addr); }
        else if (contractName == "seniorTranche") { seniorTranche = EpochTrancheLike(addr); }
        else if (contractName == "reserve") { reserve = ReserveLike(addr); }
        else if (contractName == "assessor") { assessor = AssessorLike(addr); }
        else revert();
    }

    function closeEpoch() external {
        require(lastEpochExecuted < currentEpoch());

        uint closingEpoch = safeAdd(lastEpochExecuted, 1);

        (uint orderJuniorSupply, uint orderJuniorRedeem) = juniorTranche.getTotalOrders(closingEpoch);
        (uint orderSeniorSupply, uint orderSeniorRedeem) = seniorTranche.getTotalOrders(closingEpoch);

        epochNAV = assessor.calcNAV();

        // calculate in DAI
        epochSeniorTokenPrice = assessor.calcSeniorTokenPrice(epochNAV);
        epochJuniorTokenPrice = assessor.calcJuniorTokenPrice(epochNAV);

        epochSeniorDebt = assessor.seniorDebt();
        epochSeniorBalance = assessor.seniorBalance();

        /// calculate currency amounts
        order.seniorRedeem = rmul(orderSeniorRedeem, epochSeniorTokenPrice);
        order.juniorRedeem = rmul(orderJuniorRedeem, epochJuniorTokenPrice);
        order.juniorSupply = orderJuniorSupply;
        order.seniorSupply = orderSeniorSupply;

        /// can orders be to 100% fulfilled
        if (validate(orderSeniorRedeem, orderJuniorRedeem, orderSeniorSupply, orderJuniorSupply)) {

            executeEpoch(orderSeniorRedeem, orderJuniorRedeem, orderSeniorSupply, orderJuniorSupply);
            return;
        }

        submissionPeriod = true;
    }

    /// number denominated in WAD
    /// all variables expressed as currency
    function submitSolution(uint redeemSenior, uint redeemJunior, uint supplySenior, uint supplyJunior) public {
        require(submissionPeriod == true);
        uint score = scoreSolution(redeemSenior, redeemJunior, supplySenior, supplyJunior);

        if (score < bestSubScore) {
            return;
        }

        if(validate(redeemSenior, redeemJunior, supplySenior, supplyJunior)) {
            if (challengePeriodEnd == 0) {
                challengePeriodEnd = safeAdd(block.timestamp, challengeTime);
            }

            bestSubmission.seniorRedeem = redeemSenior;
            bestSubmission.juniorRedeem = redeemJunior;
            bestSubmission.juniorSupply = supplyJunior;
            bestSubmission.seniorSupply = supplySenior;
        }
    }

    function scoreSolution(uint redeemSenior, uint redeemJunior, uint supplySenior, uint supplyJunior) public pure returns(uint) {
        // todo improve scoring func
        return safeAdd(safeAdd(safeMul(redeemSenior, 10000), safeMul(redeemJunior, 1000)),safeAdd(safeMul(supplyJunior, 100), safeMul(supplySenior, 10)));

    }

    // all parameters in WAD and denominated in currency
    function validate(uint redeemSenior, uint redeemJunior, uint supplySenior, uint supplyJunior) public returns (bool) {
        uint newReserve = safeSub(safeSub(safeAdd(safeAdd(reserve.balance(), supplyJunior), supplySenior), redeemSenior), redeemJunior);

        // max ratio constraint
        if (newReserve >= assessor.maxReserve()) {
            return false;
        }

        // max currency available constraint

        // todo implement all constraints
        return true;
    }

    function executeEpoch() public {
        require(block.timestamp >= challengePeriodEnd && challengePeriodEnd != 0);
        executeEpoch(bestSubmission.seniorRedeem ,bestSubmission.juniorRedeem, bestSubmission.seniorSupply, bestSubmission.juniorSupply);
    }

    function executeEpoch(uint redeemSenior, uint redeemJunior, uint supplySenior, uint supplyJunior) internal {

        // todo call transfers on operators

        // todo re-balance of senior debt

        // todo update update seniorBalance;

        lastEpochExecuted++;
        submissionPeriod = false;
        challengePeriodEnd = 0;
        bestSubScore = 0;
    }
}
