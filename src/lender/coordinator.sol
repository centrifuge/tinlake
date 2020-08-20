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
pragma experimental ABIEncoderV2;

import "./ticker.sol";
import "tinlake-auth/auth.sol";

contract DataTypes {
    struct Fixed27 {
        uint value;
    }
}

interface EpochTrancheLike {
    function epochUpdate(uint epochID, uint supplyFulfillment_,
        uint redeemFulfillment_, uint tokenPrice_) external;
    function getTotalOrders(uint epochID) external view returns(uint totalSupply, uint totalRedeem);
}

interface ReserveLike {
    function updateMaxCurrency(uint currencyAmount) external;
    function totalBalance() external returns (uint);
}

contract AssessorLike is DataTypes {
    function calcSeniorTokenPrice(uint NAV_) external returns(Fixed27 memory tokenPrice);
    function calcJuniorTokenPrice(uint NAV_) external returns(Fixed27 memory tokenPrice);
    function maxReserve() external view returns(uint);
    function calcNAV() external returns (uint);
    function seniorDebt() external returns(uint);
    function seniorBalance() external returns(uint);
    function seniorRatioBounds() external view returns(Fixed27 memory minSeniorRatio, Fixed27 memory maxSeniorRatio);
    function updateSenior(uint seniorDebt, uint seniorBalance) external;
}

contract EpochCoordinator is Ticker, Auth, DataTypes  {
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
    bool public gotValidPoolConSubmission;
    OrderSummary public order;

    Fixed27 public epochSeniorTokenPrice;
    Fixed27 public epochJuniorTokenPrice;

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
        order.seniorRedeem = rmul(orderSeniorRedeem, epochSeniorTokenPrice.value);
        order.juniorRedeem = rmul(orderJuniorRedeem, epochJuniorTokenPrice.value);
        order.juniorSupply = orderJuniorSupply;
        order.seniorSupply = orderSeniorSupply;

        if (orderSeniorRedeem == 0 && orderSeniorRedeem == 0 &&
            orderSeniorSupply == 0 && orderSeniorSupply == 0) {
           // executeEpoch(0, 0, 0, 0);
        }

        /// can orders be to 100% fulfilled
        if (validate(orderSeniorRedeem, orderJuniorRedeem,
            orderSeniorSupply, orderJuniorSupply) == 0) {

            executeEpoch(orderSeniorRedeem, orderJuniorRedeem,
                orderSeniorSupply, orderJuniorSupply);
            return;
        }

        submissionPeriod = true;
    }

    /// number denominated in WAD
    /// all variables expressed as currency
    function saveNewOptimum(uint seniorRedeem, uint juniorRedeem, uint juniorSupply,
        uint seniorSupply, uint score) internal {

        bestSubmission.seniorRedeem = seniorRedeem;
        bestSubmission.juniorRedeem = juniorRedeem;
        bestSubmission.juniorSupply = juniorSupply;
        bestSubmission.seniorSupply = seniorSupply;

        bestSubScore = score;
    }

    function submitSolution(uint seniorRedeem, uint juniorRedeem,
        uint juniorSupply, uint seniorSupply) public returns(int) {

        int valid = _submitSolution(seniorRedeem, juniorRedeem, juniorSupply, seniorSupply);

        if(valid == 0 && minChallengePeriodEnd == 0) {
            minChallengePeriodEnd = safeAdd(block.timestamp, challengeTime);
        }
        return valid;
    }

    function _submitSolution(uint seniorRedeem, uint juniorRedeem,
        uint juniorSupply, uint seniorSupply) internal returns(int) {

        require(submissionPeriod == true);

        (uint newReserve, int valid) = validateCoreConstraints(seniorRedeem, juniorRedeem, seniorSupply, juniorSupply);
        if(valid != 0) {
            // every proposed solution needs to satisfy the core constraints
            // solution is not valid => -2
            return -2;
        }

        if(validatePoolConstraints(newReserve, calcSeniorState(seniorRedeem, seniorSupply,
            epochSeniorDebt, epochSeniorBalance)) == 0) {

            uint score = scoreSolution(seniorRedeem, juniorRedeem, seniorSupply, juniorSupply);

            if(gotValidPoolConSubmission == false) {
                gotValidPoolConSubmission = true;
                saveNewOptimum(seniorRedeem, juniorRedeem, juniorSupply, seniorSupply, score);
                // solution is new best => 0
                return 0;
            }

            if (score < bestSubScore) {
                // solution is not the best => -1
                return -1;
            }

            saveNewOptimum(seniorRedeem, juniorRedeem, juniorSupply, seniorSupply, score);

            // solution is new best => 0
            return 0;
        }

        // proposed solution does not satisfy all pool constraints
        // if we never received a solution which satisfies all constraints for this epoch
        // we might accept it as an improvement
        if (gotValidPoolConSubmission == false) {
            return _improvementScoreCase(seniorRedeem, juniorRedeem, juniorSupply, seniorSupply);
        }

        // proposed solution doesn't satisfy the pool constraints but a previous submission did
        // previous solutions satisfied all constraints
        return -3;
    }

    function abs(uint x, uint y) public view returns(uint delta) {
        if(x == y) {
            // todo add explanation
            return 1;
        }

        if(x > y) {
            return safeSub(x, y);
        }
        return safeSub(y, x);
    }

    function checkRatioInRange(Fixed27 memory ratio, Fixed27 memory minRatio,
        Fixed27 memory maxRatio) public view returns (bool) {
        if (ratio.value >= minRatio.value && ratio.value <= maxRatio.value ) {
            return true;
        }
        return false;
    }

    function _improvementScoreCase(uint seniorRedeem, uint juniorRedeem,
        uint juniorSupply, uint seniorSupply) internal returns(int) {
        Fixed27 memory currSeniorRatio = Fixed27(calcSeniorRatio(safeAdd(epochSeniorBalance, epochSeniorDebt),
            epochNAV, epochReserve));

        if(bestSubScore == 0) {
            // define no orders score as benchmark if no previous submission exists
            bestSubScore = scoreImprovement(currSeniorRatio, currSeniorRatio, epochReserve);
        }

        uint newReserve = calcNewReserve(seniorRedeem, juniorRedeem, seniorSupply, juniorSupply);

        Fixed27 memory newSeniorRatio = Fixed27(calcSeniorRatio(calcSeniorState( seniorRedeem, seniorSupply,
            epochSeniorDebt, epochSeniorBalance), epochNAV, newReserve));

        uint score =  scoreImprovement(newSeniorRatio, currSeniorRatio, newReserve);

        if (score < bestSubScore) {
            // solution is not the best => -1
            return -1;
        }

        // solution doesn't satisfy all pool constraints but improves the current violation
        saveNewOptimum(seniorRedeem, juniorRedeem, juniorSupply, seniorSupply, score);
        return 0;
    }

    // returns the normalized distance (maxReserve = ONE) from the newReserve and maxReserve/2
    function scoreDistanceReserve(Fixed27 memory newReserve_) public view returns (uint score) {
        return rmul(1000, rdiv(ONE, abs(safeDiv(ONE, 2), newReserve_.value)));
    }

    function scoreImprovement(Fixed27 memory newSeniorRatio, Fixed27 memory currSeniorRatio,
        uint newReserve_) public  returns(uint) {

        (Fixed27 memory minSeniorRatio, Fixed27 memory maxSeniorRatio) = assessor.seniorRatioBounds();

        // normalize reserve by defining maxReserve as ONE
        Fixed27 memory normalizedNewReserve = Fixed27(rdiv(newReserve_, assessor.maxReserve()));

        // current ratio is healthy
        if (checkRatioInRange(currSeniorRatio, minSeniorRatio, maxSeniorRatio) == true) {

            // the new proposed solution would violate the ratio constraints
            if (checkRatioInRange(newSeniorRatio, minSeniorRatio, maxSeniorRatio) == false)
            {
                return 0;
            }
            // only points for maxRatio improvement

            return scoreDistanceReserve(normalizedNewReserve);

        }

        // gas optimized implementation
        // abs of ratio can never be zero
        uint score = rmul(10000, rdiv(ONE, abs(newSeniorRatio.value,
            safeDiv(safeAdd(minSeniorRatio.value, maxSeniorRatio.value), 2))));

        // ratio constraints and maxReserve are in the current state violated
        // additional score
        if (epochReserve >= assessor.maxReserve()) {
           score = safeAdd(score, scoreDistanceReserve(normalizedNewReserve));
        }
        return score;
    }

    function scoreSolution(uint seniorRedeem, uint juniorRedeem,
        uint juniorSupply, uint seniorSupply) public pure returns(uint) {

        // todo improve scoring func
        return safeAdd(safeAdd(safeMul(seniorRedeem, 10000), safeMul(juniorRedeem, 1000)),
            safeAdd(safeMul(juniorSupply, 100), safeMul(seniorSupply, 10)));
    }


    /*
        returns newReserve for gas efficiency reasons to only calc it once
    */
    function validateCoreConstraints(uint seniorRedeem, uint juniorRedeem,
        uint seniorSupply, uint juniorSupply) public view returns (uint newReserve, int err) {

        uint currencyAvailable = safeAdd(safeAdd(epochReserve, seniorSupply), juniorSupply);
        uint currencyOut = safeAdd(seniorRedeem, juniorRedeem);


        // constraint 1: currency available
        if (currencyOut > currencyAvailable) {
            // currencyAvailableConstraint => -1
            return (0, -1);
        }

        uint newReserve = safeSub(currencyAvailable, currencyOut);
        // constraint 2: max reserve
        if (newReserve > assessor.maxReserve()) {
            // maxReserveConstraint => -2
            return (0, -2);
        }

        // constraint 3: max order
        if (seniorSupply > order.seniorSupply ||
        juniorSupply > order.juniorSupply ||
        seniorRedeem > order.seniorRedeem ||
            juniorRedeem > order.juniorRedeem) {
            // maxOrderConstraint => -3
            return (0, -3);
        }

        // successful => 0
        return (newReserve, 0);
    }

    function validatePoolConstraints(uint newReserve, uint newSeniorAsset) public view returns (int err) {
        uint assets = safeAdd(epochNAV, newReserve);

        (Fixed27 memory minSeniorRatio, Fixed27 memory maxSeniorRatio) = assessor.seniorRatioBounds();

        // constraint 4: min senior ratio constraint
        if (newSeniorAsset < rmul(assets, minSeniorRatio.value)) {
            // minSeniorRatioConstraint => -4
            return -4;
        }
        // constraint 5: max senior ratio constraint
        if (newSeniorAsset > rmul(assets, maxSeniorRatio.value)) {
            // maxSeniorRatioConstraint => -5
            return -5;
        }
        // successful => 0
        return 0;
    }

    // all parameters in WAD and denominated in currency
    function validate(uint seniorRedeem, uint juniorRedeem,
        uint seniorSupply, uint juniorSupply) public view returns (int) {

        (uint newReserve, int err) = validateCoreConstraints(seniorRedeem, juniorRedeem, seniorSupply, juniorSupply);
        if(err != 0) {
            return err;
        }

        return validatePoolConstraints(newReserve, calcSeniorState(seniorRedeem, seniorSupply,
            epochSeniorDebt, epochSeniorBalance));
    }

    function executeEpoch() public {
        require(block.timestamp >= minChallengePeriodEnd && minChallengePeriodEnd != 0);

        executeEpoch(bestSubmission.seniorRedeem ,bestSubmission.juniorRedeem,
            bestSubmission.seniorSupply, bestSubmission.juniorSupply);
    }

    function calcSeniorState(uint seniorRedeem, uint seniorSupply,
        uint seniorDebt, uint seniorBalance) public view returns (uint seniorAsset) {

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

    function reBalanceSeniorDebt(uint seniorAsset,
        uint currSeniorRatio) public view returns (uint seniorDebt_, uint seniorBalance_) {

        uint seniorDebt = rmul(seniorAsset, currSeniorRatio);
        return (seniorDebt, safeSub(seniorAsset, seniorDebt));
    }

    function calcFulfillment(uint amount, uint totalOrder) public view returns(Fixed27 memory percent) {
        if(amount == 0 || totalOrder == 0) {
            return Fixed27(0);
        }
        return Fixed27(rdiv(amount, totalOrder));
    }

    function calcNewReserve(uint seniorRedeem, uint juniorRedeem,
        uint seniorSupply, uint juniorSupply) public view returns(uint) {

        return safeSub(safeAdd(safeAdd(epochReserve, seniorSupply), juniorSupply),
            safeAdd(seniorRedeem, juniorRedeem));
    }

    function executeEpoch(uint seniorRedeem, uint juniorRedeem,
        uint seniorSupply, uint juniorSupply) internal {

        uint epochID = lastEpochExecuted+1;

        seniorTranche.epochUpdate(epochID, calcFulfillment(seniorSupply, order.seniorSupply).value,
            calcFulfillment(seniorRedeem, order.seniorRedeem).value,
            epochSeniorTokenPrice.value);

        juniorTranche.epochUpdate(epochID, calcFulfillment(juniorSupply, order.juniorSupply).value,
            calcFulfillment(juniorRedeem, order.juniorRedeem).value,
            epochSeniorTokenPrice.value);

        uint seniorAsset = calcSeniorState(seniorRedeem, seniorSupply,
            assessor.seniorDebt(), assessor.seniorBalance());

        uint newReserve = calcNewReserve(seniorRedeem, juniorRedeem
        , seniorSupply, juniorSupply);

        (uint seniorDebt, uint seniorBalance) = reBalanceSeniorDebt(seniorAsset,
            calcSeniorRatio(seniorAsset, epochNAV, newReserve));

        assessor.updateSenior(seniorDebt, seniorBalance);

        lastEpochExecuted = epochID;
        submissionPeriod = false;
        minChallengePeriodEnd = 0;
        bestSubScore = 0;
        gotValidPoolConSubmission = false;
    }
}
