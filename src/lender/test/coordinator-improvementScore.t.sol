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

import "./coordinator-base.t.sol";

contract CoordinatorImprovementScoreTest is CoordinatorTest, FixedPoint {
    function setUp() public {
        super.setUp();

    }

    function testScoreRatioImprovement() public {
        LenderModel memory model = getDefaultModel();
        initTestConfig(model);

        //  0.75 >= seniorRatio <= 0.85
        emit log_named_uint("maxSeniorRatio", model.maxSeniorRatio);
        emit log_named_uint("maxSeniorRatio", model.minSeniorRatio);

        Fixed27 memory newSeniorRatio = Fixed27(92 * 10**25);

        uint score = coordinator.scoreRatioImprovement(newSeniorRatio);

        newSeniorRatio = Fixed27(91 * 10**25);
        uint betterScore = coordinator.scoreRatioImprovement(newSeniorRatio);

        assertTrue(betterScore > score);

        // healthy
        newSeniorRatio = Fixed27(83 * 10**25);
        Fixed27 memory healthyRatio = Fixed27(81 * 10**25);
        uint healthyScore1 = coordinator.scoreRatioImprovement(newSeniorRatio);
        uint healthyScore2 = coordinator.scoreRatioImprovement(healthyRatio);
        assertEq(healthyScore1, healthyScore2);
    }

    function testReserveImprovement() public {
        LenderModel memory model = getDefaultModel();
        model.maxReserve = 1000 ether;
        initTestConfig(model);

        uint score = coordinator.scoreReserveImprovement(1200 ether);
        uint betterScore = coordinator.scoreReserveImprovement(1100 ether);
        uint healthyScore = coordinator.scoreReserveImprovement(1000 ether);
        uint secondHealthScore = coordinator.scoreReserveImprovement(900 ether);

        assertTrue(betterScore > score);
        assertEq(healthyScore, secondHealthScore);
    }


    // test function with submitSolution
    function testScoreImprovementRatio() public {
        LenderModel memory model = getDefaultModel();
        model.seniorRedeemOrder = 1000 ether;
        model.maxReserve = 1000 ether;

        // sets ratio to 0.9230
        model.reserve = 500 ether;
        model.seniorBalance = 500 ether;

        initTestConfig(model);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();

        //  0.75 >= seniorRatio <= 0.85
        emit log_named_uint("maxSeniorRatio", model.maxSeniorRatio);
        emit log_named_uint("maxSeniorRatio", model.minSeniorRatio);

        uint currentRatio = coordinator.calcSeniorRatio(coordinator.calcSeniorAssetValue(0,0,safeAdd(model.seniorDebt, model.seniorBalance), model.reserve, model.NAV),
            model.NAV, model.reserve);

        // check if ratio is broken
        assertTrue(currentRatio > model.maxSeniorRatio);


        ModelInput memory solution = ModelInput({
            seniorRedeem : 0 ether,
            juniorSupply : 0 ether,
            seniorSupply : 20 ether,
            juniorRedeem : 0 ether
            });

        uint newRatio = calcNewSeniorRatio(model, solution);

        //newRatio would be bad compared with current ratio
        assertTrue(newRatio > currentRatio);

        // benchmark status is better there for no best solution
        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());
        // no solution in feasible region
        assertTrue(coordinator.gotValidPoolConSubmission() == false);

        // senior redeem improves the ratio
         solution = ModelInput({
            seniorRedeem : 20 ether,
            juniorSupply : 0 ether,
            seniorSupply : 0 ether,
            juniorRedeem : 0 ether
            });

        newRatio = calcNewSeniorRatio(model, solution);
        // check if ratio is still broken but better
        assertTrue(newRatio > model.maxSeniorRatio);

        // benchmark status is better there for no best solution
        assertEq(submitSolution(solution), coordinator.NEW_BEST());
        // no solution in feasible region
        assertTrue(coordinator.gotValidPoolConSubmission() == false);
        assertEq(coordinator.bestSubScore(), 0);


        // senior redeem improves the ratio
        solution = ModelInput({
            seniorRedeem : 80 ether,
            juniorSupply : 0 ether,
            seniorSupply : 0 ether,
            juniorRedeem : 0 ether
            });


        newRatio = calcNewSeniorRatio(model, solution);
        // check if ratio is still broken but better
        assertTrue(newRatio > model.maxSeniorRatio);


        assertEq(submitSolution(solution), coordinator.NEW_BEST());
        // no solution in feasible region
        assertTrue(coordinator.gotValidPoolConSubmission() == false);
        assertEq(coordinator.bestSubScore(), 0);


        // push ratio in feasible region

        // senior redeem improves the ratio
        solution = ModelInput({
            seniorRedeem : 500 ether,
            juniorSupply : 100 ether,
            seniorSupply : 0 ether,
            juniorRedeem : 0 ether
            });

        newRatio = calcNewSeniorRatio(model, solution);

        // check if ratio is still broken but better
        assertTrue(newRatio <= model.maxSeniorRatio);

        assertEq(submitSolution(solution), coordinator.NEW_BEST());
        // no solution in feasible region
        assertTrue(coordinator.gotValidPoolConSubmission() == true);
        // should have a score bigger than 0
        assertTrue(coordinator.bestSubScore() != 0);
    }

    function testScoreImprovementMaxReserve() public {
        LenderModel memory model = getDefaultModel();
        model.maxReserve = 200 ether;
        model.reserve = 210 ether;
        model.seniorSupplyOrder = 300 ether;
        model.juniorRedeemOrder = 300 ether;

        initTestConfig(model);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();

        uint currentRatio = coordinator.calcSeniorRatio(coordinator.calcSeniorAssetValue(0,0,safeAdd(model.seniorDebt, model.seniorBalance), model.reserve, model.NAV),
            model.NAV, model.reserve);

        // check ratio okay
        assertTrue(currentRatio <= model.maxSeniorRatio);
        assertTrue(currentRatio >= model.minSeniorRatio);

        //
        ModelInput memory solution = ModelInput({
            seniorRedeem : 0 ether,
            juniorSupply : 0 ether,
            seniorSupply : 10 ether,
            juniorRedeem : 0 ether
            });


        // benchmark status is better there for no best solution
        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());
        assertTrue(coordinator.gotValidPoolConSubmission() == false);


        solution = ModelInput({
            seniorRedeem : 0 ether,
            juniorSupply : 0 ether,
            seniorSupply : 0 ether,
            juniorRedeem : 5 ether
            });

        // benchmark status is better there for no best solution
        assertEq(submitSolution(solution), coordinator.NEW_BEST());
        assertTrue(coordinator.gotValidPoolConSubmission() == false);


        // destroy ratio but fix reserve
        solution = ModelInput({
            seniorRedeem : 0 ether,
            juniorSupply : 0 ether,
            seniorSupply : 270 ether,
            juniorRedeem : 300 ether
            });


        uint newRatio = calcNewSeniorRatio(model, solution);

        // check ratio okay
        assertTrue(newRatio > model.maxSeniorRatio);

        // benchmark status is better there for no best solution
        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());
        assertTrue(coordinator.gotValidPoolConSubmission() == false);


        // fix reserve constraint
        // destroy ratio but fix reserve
        solution = ModelInput({
            seniorRedeem : 0 ether,
            juniorSupply : 0 ether,
            seniorSupply : 0 ether,
            juniorRedeem : 30 ether
            });

        // benchmark status is better there for no best solution
        assertEq(submitSolution(solution), coordinator.NEW_BEST());
        assertTrue(coordinator.gotValidPoolConSubmission() == true);
    }
}

