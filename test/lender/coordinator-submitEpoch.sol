// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "./coordinator-base.t.sol";

contract CoordinatorSubmitEpochTest is CoordinatorTest, FixedPoint {
    function setUp() public override {
        super.setUp();
    }

    function testMaxImprovementScore() public {
        // 1 trillion order
        uint256 maxOrder = 10 ** 18 * 10 ** 18;
        uint256 score = coordinator.scoreSolution(maxOrder, maxOrder, maxOrder, maxOrder);

        // should not produce integer overflow
        assertTrue(score <= type(uint256).max);
    }

    function testFailNoSubmission() public {
        coordinator.submitSolution(10 ether, 10 ether, 10 ether, 10 ether);
    }

    function testFailNoSubmissionLongTime() public {
        hevm.warp(block.timestamp + 20 days);
        coordinator.submitSolution(10 ether, 10 ether, 10 ether, 10 ether);
    }

    function testFailNoSubmissionRequired() public {
        LenderModel memory model = getDefaultModel();
        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        coordinator.submitSolution(10 ether, 10 ether, 10 ether, 10 ether);
    }

    function testSubmitSolution() public {
        LenderModel memory model = getDefaultModel();
        model.seniorSupplyOrder = 10000 ether;

        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        ModelInput memory solution =
            ModelInput({seniorSupply: 1 ether, juniorSupply: 2 ether, seniorRedeem: 3 ether, juniorRedeem: 4 ether});

        assertEq(submitSolution(solution), coordinator.SUCCESS());
        compareWithBest(solution);

        // challenge period started
        uint256 challengeEnd = block.timestamp + 1 hours;
        assertEq(coordinator.minChallengePeriodEnd(), challengeEnd);

        hevm.warp(block.timestamp + 2 hours);

        ModelInput memory betterSolution =
            ModelInput({seniorSupply: 2 ether, juniorSupply: 3 ether, seniorRedeem: 4 ether, juniorRedeem: 5 ether});

        // new best
        assertEq(submitSolution(betterSolution), coordinator.SUCCESS());

        // better solution should be new best
        compareWithBest(betterSolution);

        // no new challenge end
        assertEq(coordinator.minChallengePeriodEnd(), challengeEnd);

        hevm.warp(block.timestamp + 2 hours);

        // re submit solution with lower score
        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());

        // better solution should be still the best
        compareWithBest(betterSolution);

        // re submit solution with lower score
        solution.seniorSupply = 2 ether;
        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());

        // better solution should be still the best
        compareWithBest(betterSolution);

        // submit invalid solution
        solution.seniorSupply = 100000000 ether;
        assertEq(submitSolution(solution), coordinator.ERR_MAX_ORDER());
    }

    function checkPoolPrecondition(LenderModel memory model, bool currSeniorRatioInRange, bool reserveHealthy) public {
        // check if current ratio is healthy
        Fixed27 memory currSeniorRatio = Fixed27(
            assessor.calcSeniorRatio(coordinator.epochSeniorAsset(), coordinator.epochNAV(), coordinator.epochReserve())
        );

        assertTrue(
            coordinator.checkRatioInRange(currSeniorRatio.value, model.minSeniorRatio, model.maxSeniorRatio)
                == currSeniorRatioInRange
        );
        assertTrue((coordinator.epochReserve() <= assessor.maxReserve()) == reserveHealthy);
    }

    // from unhealthy to healthy with submission
    function testSubmitEpochUnhealthyState() public {
        LenderModel memory model = getDefaultModel();
        model.seniorSupplyOrder = 10000 ether;
        model.maxReserve = 1000 ether;

        // reserve constraint violated
        // 800 ether
        model.reserve = 1150 ether;
        model.seniorBalance = 850 ether;

        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        bool currSeniorRatioInRange = true;
        bool reserveHealthy = false;
        checkPoolPrecondition(model, currSeniorRatioInRange, reserveHealthy);

        ModelInput memory solution =
            ModelInput({seniorSupply: 0 ether, juniorSupply: 0 ether, seniorRedeem: 100 ether, juniorRedeem: 100 ether});

        assertEq(submitSolution(solution), coordinator.SUCCESS());
        assertTrue(coordinator.gotFullValidSolution() == true);
    }

    function testSubmitImprovement() public {
        LenderModel memory model = getDefaultModel();
        model.seniorSupplyOrder = 10000 ether;
        model.juniorRedeemOrder = 10000 ether;
        model.maxReserve = 1000 ether;
        model.reserve = 1150 ether;

        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        bool currSeniorRatioInRange = false;
        bool reserveHealthy = false;
        checkPoolPrecondition(model, currSeniorRatioInRange, reserveHealthy);

        ModelInput memory solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 0 ether, seniorSupply: 800 ether, juniorRedeem: 0 ether});

        assertEq(submitSolution(solution), coordinator.SUCCESS());
        assertTrue(coordinator.gotFullValidSolution() == false);

        solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 0 ether, seniorSupply: 800 ether, juniorRedeem: 500 ether});

        assertEq(submitSolution(solution), coordinator.SUCCESS());
        assertTrue(coordinator.gotFullValidSolution() == false);

        solution = ModelInput({
            seniorRedeem: 0 ether,
            juniorSupply: 0 ether,
            seniorSupply: 300 ether,
            juniorRedeem: 1000 ether
        });

        assertEq(submitSolution(solution), coordinator.SUCCESS());
        assertTrue(coordinator.gotFullValidSolution() == false);

        // solution would satisfy all constraints
        solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 0 ether, seniorSupply: 0 ether, juniorRedeem: 950 ether});

        assertEq(submitSolution(solution), coordinator.SUCCESS());
        assertTrue(coordinator.gotFullValidSolution() == true);

        // should be not possible to submit unhealthy solutions again
        solution = ModelInput({
            seniorRedeem: 0 ether,
            juniorSupply: 0 ether,
            seniorSupply: 300 ether,
            juniorRedeem: 1000 ether
        });

        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());
        assertTrue(coordinator.gotFullValidSolution() == true);

        // submit better healthy solution
        // solution would satisfy all constraints
        solution = ModelInput({
            seniorRedeem: 50 ether,
            juniorSupply: 0 ether,
            seniorSupply: 250 ether,
            juniorRedeem: 950 ether
        });

        assertEq(submitSolution(solution), coordinator.SUCCESS());
        assertTrue(coordinator.gotFullValidSolution() == true);
    }

    function submitSolutionWorseThanBenchmark() public {
        LenderModel memory model = getDefaultModel();
        model.seniorSupplyOrder = 10000 ether;
        model.juniorRedeemOrder = 10000 ether;
        model.maxReserve = 1000 ether;
        model.reserve = 1150 ether;

        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        bool currSeniorRatioInRange = false;
        bool reserveHealthy = false;

        // current seniorRatio below minSeniorRatio & maxReserve violated
        checkPoolPrecondition(model, currSeniorRatioInRange, reserveHealthy);

        ModelInput memory solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 100 ether, seniorSupply: 0 ether, juniorRedeem: 0 ether});

        assertEq(submitSolution(solution), coordinator.ERR_MAX_ORDER());
    }

    function testNoImprovementPossibleReserveViolated() public {
        LenderModel memory model = getDefaultModel();
        model.maxReserve = 200 ether;
        model.reserve = 210 ether;
        // we only have supplies
        model.juniorRedeemOrder = 0;
        model.seniorRedeemOrder = 0;

        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        // no improvement possible only zero submission
        ModelInput memory solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 0 ether, seniorSupply: 0 ether, juniorRedeem: 0 ether});

        bool currSeniorRatioInRange = true;
        bool reserveHealthy = false;

        // reserve violated
        checkPoolPrecondition(model, currSeniorRatioInRange, reserveHealthy);

        assertTrue(coordinator.minChallengePeriodEnd() == 0);
        assertEq(submitSolution(solution), coordinator.NEW_BEST());
        assertTrue(coordinator.minChallengePeriodEnd() != 0);

        solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 0 ether, seniorSupply: 1 ether, juniorRedeem: 0 ether});

        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());
    }

    function testNoImprovementPossibleRatioViolated() public {
        LenderModel memory model = getDefaultModel();
        model.maxReserve = 10000 ether;
        model.reserve = 1000 ether;
        // we only have supplies
        model.juniorRedeemOrder = 0;
        model.seniorRedeemOrder = 0;
        model.seniorSupplyOrder = 0;

        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        // no improvement possible only zero submission
        ModelInput memory solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 0 ether, seniorSupply: 0 ether, juniorRedeem: 0 ether});

        bool currSeniorRatioInRange = false;
        bool reserveHealthy = true;
        //  senior ratio too low
        checkPoolPrecondition(model, currSeniorRatioInRange, reserveHealthy);

        assertEq(submitSolution(solution), coordinator.NEW_BEST());

        solution =
            ModelInput({seniorRedeem: 0 ether, juniorSupply: 1 ether, seniorSupply: 0 ether, juniorRedeem: 0 ether});

        assertEq(submitSolution(solution), coordinator.ERR_NOT_NEW_BEST());
    }
}
