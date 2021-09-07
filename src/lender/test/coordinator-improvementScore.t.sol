// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./coordinator-base.t.sol";

contract CoordinatorImprovementScoreTest is CoordinatorTest, FixedPoint {
    function setUp() public override {
        super.setUp();

    }

    function testScoreRatioImprovement() public {
        LenderModel memory model = getDefaultModel();
        initTestConfig(model);

        //  0.75 >= seniorRatio <= 0.85
        emit log_named_uint("maxSeniorRatio", model.maxSeniorRatio);
        emit log_named_uint("maxSeniorRatio", model.minSeniorRatio);

        Fixed27 memory newSeniorRatio = Fixed27(92 * 10**25);

        uint score = coordinator.scoreRatioImprovement(newSeniorRatio.value);

        newSeniorRatio = Fixed27(91 * 10**25);
        uint betterScore = coordinator.scoreRatioImprovement(newSeniorRatio.value);

        assertTrue(betterScore > score);

        // healthy
        newSeniorRatio = Fixed27(83 * 10**25);
        Fixed27 memory healthyRatio = Fixed27(81 * 10**25);
        uint healthyScore1 = coordinator.scoreRatioImprovement(newSeniorRatio.value);
        uint healthyScore2 = coordinator.scoreRatioImprovement(healthyRatio.value);
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
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        //  0.75 >= seniorRatio <= 0.85
        emit log_named_uint("maxSeniorRatio", model.maxSeniorRatio);
        emit log_named_uint("maxSeniorRatio", model.minSeniorRatio);

        uint currentRatio = assessor.calcSeniorRatio(assessor.calcSeniorAssetValue(0,0,safeAdd(model.seniorDebt, model.seniorBalance), model.reserve, model.NAV),
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
        assertTrue(coordinator.gotFullValidSolution() == false);

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
        assertTrue(coordinator.gotFullValidSolution() == false);
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
        assertTrue(coordinator.gotFullValidSolution() == false);
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
        assertTrue(coordinator.gotFullValidSolution() == true);
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
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        uint currentRatio = assessor.calcSeniorRatio(assessor.calcSeniorAssetValue(0,0,safeAdd(model.seniorDebt, model.seniorBalance), model.reserve, model.NAV),
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
        assertTrue(coordinator.gotFullValidSolution() == false);


        solution = ModelInput({
            seniorRedeem : 0 ether,
            juniorSupply : 0 ether,
            seniorSupply : 0 ether,
            juniorRedeem : 5 ether
            });

        // benchmark status is better there for no best solution
        assertEq(submitSolution(solution), coordinator.NEW_BEST());
        assertTrue(coordinator.gotFullValidSolution() == false);


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
        assertTrue(coordinator.gotFullValidSolution() == false);


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
        assertTrue(coordinator.gotFullValidSolution() == true);
    }

    function testScoreRatioImprovementEdge() public {
        LenderModel memory model = getDefaultModel();
        model.maxReserve = 200 ether;

        initTestConfig(model);

        // newReserve <= maxReserve
        uint newReserve = 199 ether;
        assertEq(coordinator.scoreReserveImprovement(newReserve), coordinator.BIG_NUMBER());
        // newReserve == maxReserve
        newReserve = 200 ether;
        assertEq(coordinator.scoreReserveImprovement(newReserve), coordinator.BIG_NUMBER());

        assertTrue(coordinator.scoreReserveImprovement(201 ether) > coordinator.scoreReserveImprovement(202 ether));
    }

    function testScoreRatioImprovementZeroMaxReserve() public {
        LenderModel memory model = getDefaultModel();
        model.maxReserve = 0;

        initTestConfig(model);
        assertTrue(coordinator.scoreReserveImprovement(201 ether) > coordinator.scoreReserveImprovement(202 ether));
        assertEq(coordinator.scoreReserveImprovement(0), coordinator.BIG_NUMBER());

        uint lowestScore = coordinator.scoreReserveImprovement(type(uint256).max);
        uint lowScore = coordinator.scoreReserveImprovement(10*18 * 1 ether);

        assertTrue(lowScore > lowestScore);
    }
}

