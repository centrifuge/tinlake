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
    function getTotalOrders(uint epochID) external view returns(uint totalSupply, uint totalRedeem);
}

interface ReserveLike {
    function updateMaxCurrency(uint currencyAmount) external;
    function totalBalance() external returns (uint);
}

interface AssessorLike {
    function calcSeniorTokenPrice(uint NAV_) external returns(uint);
    function calcJuniorTokenPrice(uint NAV_) external returns(uint);
    function maxReserve() external view returns(uint);
    function calcNAV() external returns (uint);
    function seniorDebt() external returns(uint);
    function seniorBalance() external returns(uint);
    function seniorRatioBounds() external view returns(uint minSeniorRatio, uint maxSeniorRatio);
    function updateSenior(uint seniorDebt, uint seniorBalance) external;

}

contract EpochCoordinator is Ticker, Auth  {
    EpochTrancheLike juniorTranche;
    EpochTrancheLike seniorTranche;

    ReserveLike reserve;
    AssessorLike assessor;

    uint public lastEpochExecuted;

    struct OrderSummary {
        uint  seniorRedeem;
        uint  juniorRedeem;
        uint  juniorSupply;
        uint  seniorSupply;
    }

    OrderSummary public bestSubmission;
    uint public  bestSubScore;
    OrderSummary public order;


    uint public epochSeniorTokenPrice;
    uint public epochJuniorTokenPrice;
    uint public epochNAV;
    uint public epochSeniorDebt;
    uint public epochSeniorBalance;
    uint public epochReserve;

    bool public submissionPeriod;

    // challenge period end timestamp
    uint public minChallengePeriodEnd;

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
        require(submissionPeriod == false);

        uint closingEpoch = safeAdd(lastEpochExecuted, 1);

        (uint orderJuniorSupply, uint orderJuniorRedeem) = juniorTranche.getTotalOrders(closingEpoch);
        (uint orderSeniorSupply, uint orderSeniorRedeem) = seniorTranche.getTotalOrders(closingEpoch);

        epochNAV = assessor.calcNAV();

        // calculate in DAI
        epochSeniorTokenPrice = assessor.calcSeniorTokenPrice(epochNAV);
        epochJuniorTokenPrice = assessor.calcJuniorTokenPrice(epochNAV);

        epochSeniorDebt = assessor.seniorDebt();
        epochSeniorBalance = assessor.seniorBalance();
        epochReserve = reserve.totalBalance();

        /// calculate currency amounts
        order.seniorRedeem = rmul(orderSeniorRedeem, epochSeniorTokenPrice);
        order.juniorRedeem = rmul(orderJuniorRedeem, epochJuniorTokenPrice);
        order.juniorSupply = orderJuniorSupply;
        order.seniorSupply = orderSeniorSupply;

        /// can orders be to 100% fulfilled
        if (validate(orderSeniorRedeem, orderJuniorRedeem, orderSeniorSupply, orderJuniorSupply) == 0) {

            executeEpoch(orderSeniorRedeem, orderJuniorRedeem, orderSeniorSupply, orderJuniorSupply);
            return;
        }

        submissionPeriod = true;
    }

    /// number denominated in WAD
    /// all variables expressed as currency
    function submitSolution(uint seniorRedeem, uint juniorRedeem, uint juniorSupply, uint seniorSupply) public returns(int) {
        require(submissionPeriod == true);
        uint score = scoreSolution(seniorRedeem, juniorRedeem, seniorSupply, juniorSupply);

        if (score < bestSubScore) {
            // solution is not the best => -1
            return -1;
        }

        if(validate(seniorRedeem, juniorRedeem, seniorSupply, juniorSupply) != 0) {
            // solution is not valid => -2
            return -2;
        }
        if (minChallengePeriodEnd == 0) {
            minChallengePeriodEnd = safeAdd(block.timestamp, challengeTime);
        }

        bestSubmission.seniorRedeem = seniorRedeem;
        bestSubmission.juniorRedeem = juniorRedeem;
        bestSubmission.juniorSupply = juniorSupply;
        bestSubmission.seniorSupply = seniorSupply;

        bestSubScore = score;

        // solution is new best => 0
        return 0;
    }

    function scoreSolution(uint seniorRedeem, uint juniorRedeem,
        uint juniorSupply, uint seniorSupply) public pure returns(uint) {
        // todo improve scoring func
        return safeAdd(safeAdd(safeMul(seniorRedeem, 10000), safeMul(juniorRedeem, 1000)),
            safeAdd(safeMul(juniorSupply, 100), safeMul(seniorSupply, 10)));
    }

    // all parameters in WAD and denominated in currency
    function validate(uint seniorRedeem, uint juniorRedeem, uint seniorSupply, uint juniorSupply) public view returns (int) {
        uint currencyAvailable = safeAdd(safeAdd(epochReserve, seniorSupply), juniorSupply);
        uint currencyOut = safeAdd(seniorRedeem, juniorRedeem);

        // constraint 1: currency available
        if (currencyOut > currencyAvailable) {
            // currencyAvailableConstraint => -1
            return -1;
        }

        uint newReserve = safeSub(currencyAvailable, currencyOut);
        // constraint 2: max reserve
        if (newReserve > assessor.maxReserve()) {
            // maxReserveConstraint => -2
            return -2;
        }

        // constraint 3: max order
        if (seniorSupply > order.seniorSupply ||
            juniorSupply > order.juniorSupply ||
            seniorRedeem > order.seniorRedeem ||
            juniorRedeem > order.juniorRedeem) {
            // maxOrderConstraint => -3
            return -3;
        }

        uint assets = safeAdd(epochNAV, newReserve);

        (uint minSeniorRatio, uint maxSeniorRatio) = assessor.seniorRatioBounds();

        // todo make seniorBalance an integer or subtract from seniorBalance and seniorDebt
        uint newSeniorBalance = safeSub(safeAdd(epochSeniorBalance, seniorSupply), seniorRedeem);
        uint newSeniorAsset = safeAdd(epochSeniorDebt, newSeniorBalance);

        // constraint 4: min senior ratio constraint
        if (newSeniorAsset < rmul(assets, minSeniorRatio)) {
            // minSeniorRatioConstraint => -4
            return -4;
        }
        // constraint 5: max senior ratio constraint
        if (newSeniorAsset > rmul(assets, maxSeniorRatio)) {
            // maxSeniorRatioConstraint => -5
            return -5;
        }
        // successful => 0
        return 0;
    }

    function executeEpoch() public {
        require(block.timestamp >= minChallengePeriodEnd && minChallengePeriodEnd != 0);
        executeEpoch(bestSubmission.seniorRedeem ,bestSubmission.juniorRedeem, bestSubmission.seniorSupply, bestSubmission.juniorSupply);
    }

    function calcSeniorState(uint seniorRedeem, uint seniorSupply,uint seniorDebt, uint seniorBalance) public view returns (uint seniorAsset) {
        return safeSub(safeAdd(safeAdd(seniorDebt, seniorBalance), seniorSupply), seniorRedeem);
    }

    function calcAssets(uint NAV, uint reserve_) public view returns(uint) {
        return safeAdd(NAV, reserve_);
    }


    function calcSeniorRatio(uint seniorAsset, uint NAV, uint reserve_) public view returns(uint) {
        uint assets = calcAssets(NAV, reserve_);
        if(assets == 0) {
            return 0;
        }
        return rdiv(seniorAsset, assets);
    }

    function reBalanceSeniorDebt(uint seniorAsset, uint currSeniorRatio) public view returns (uint seniorDebt_, uint seniorBalance_) {
        uint seniorDebt = rmul(seniorAsset, currSeniorRatio);
        return (seniorDebt, safeSub(seniorAsset, seniorDebt));
    }

    function calcFulfillment(uint amount, uint totalOrder) public view returns(uint percent) {
        if(amount == 0 || totalOrder == 0) {
            return 0;
        }
        return rdiv(amount, totalOrder);
    }

    function executeEpoch(uint seniorRedeem, uint juniorRedeem, uint seniorSupply, uint juniorSupply) internal {
        uint epochID = lastEpochExecuted+1;

        seniorTranche.epochUpdate(epochID, calcFulfillment(seniorSupply, order.seniorSupply), calcFulfillment(seniorRedeem, order.seniorRedeem), epochSeniorTokenPrice);
        juniorTranche.epochUpdate(epochID, calcFulfillment(juniorSupply, order.juniorSupply), calcFulfillment(juniorRedeem, order.juniorRedeem), epochSeniorTokenPrice);

        uint seniorAsset = calcSeniorState(seniorRedeem, seniorSupply, assessor.seniorDebt(), assessor.seniorBalance());
        uint newReserve = safeSub(safeAdd(safeAdd(epochReserve, seniorSupply), juniorSupply), safeAdd(seniorRedeem, juniorRedeem));

        (uint seniorDebt, uint seniorBalance) = reBalanceSeniorDebt(seniorAsset, calcSeniorRatio(seniorAsset, epochNAV, newReserve));

        assessor.updateSenior(seniorDebt, seniorBalance);

        lastEpochExecuted = epochID;
        submissionPeriod = false;
        minChallengePeriodEnd = 0;
        bestSubScore = 0;
    }
}
