// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "./coordinator-base.t.sol";

contract CoordinatorExecuteEpochTest is CoordinatorTest {

    struct SeniorState {
        uint seniorDebt;
        uint seniorBalance;
    }

    function setUp() public override {
        super.setUp();
    }

    function prepareExecute(LenderModel memory model_, ModelInput memory input) public {
        initTestConfig(model_);
        hevm.warp(block.timestamp + 1 days);
        assertTrue(coordinator.submissionPeriod() == false);
        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == true);

        seniorTranche.setEpochReturn(model_.seniorSupplyOrder, model_.seniorRedeemOrder);

        int result = coordinator.submitSolution(input.seniorRedeem, input.juniorRedeem, input.juniorSupply, input.seniorSupply);
        // new best solution
        assertEq(result, coordinator.SUCCESS());

        hevm.warp(block.timestamp + 1 days);
    }

    function checkTrancheUpdates(LenderModel memory model_, ModelInput memory input) public {
        assertEq(seniorTranche.values_uint("epochUpdate_supplyFulfillment"),
        rdiv(input.seniorSupply, model_.seniorSupplyOrder));

        assertEq(seniorTranche.values_uint("epochUpdate_redeemFulfillment"),
            rdiv(input.seniorRedeem, model_.seniorRedeemOrder));

        assertEq(juniorTranche.values_uint("epochUpdate_supplyFulfillment"),
            rdiv(input.juniorSupply, model_.juniorSupplyOrder));

        assertEq(juniorTranche.values_uint("epochUpdate_redeemFulfillment"),
            rdiv(input.juniorRedeem, model_.juniorRedeemOrder));
    }

    function testExecuteEpoch() public {
        LenderModel memory model_ = getDefaultModel();
        model_.seniorSupplyOrder = 300000 ether;

        ModelInput memory input = ModelInput({
            seniorSupply : 1 ether,
            juniorSupply : 2 ether,
            seniorRedeem : 3 ether,
            juniorRedeem : 4 ether

            });

        prepareExecute(model_, input);

        uint lastEpochExecuted = coordinator.lastEpochExecuted();
        coordinator.executeEpoch();

        assertEq(coordinator.lastEpochExecuted(), lastEpochExecuted+1);
        assertTrue(coordinator.submissionPeriod() == false);
        assertEq(coordinator.minChallengePeriodEnd(), 0);
        assertEq(coordinator.bestSubScore(), 0);
        checkTrancheUpdates(model_, input);

        // check for rebalancing
        uint shouldNewReserve = safeSub(safeAdd(safeAdd(model_.reserve, input.seniorSupply), input.juniorSupply),
            safeAdd(input.seniorRedeem, input.juniorRedeem));

        uint seniorAsset = assessor.calcSeniorAssetValue(input.seniorRedeem, input.seniorSupply, safeAdd(model_.seniorDebt, model_.seniorBalance), shouldNewReserve, model_.NAV);

        // change or orders delta = -2 ether
        uint shouldSeniorAsset = safeSub(safeAdd(model_.seniorDebt, model_.seniorBalance), 2 ether);

        assertEq(seniorAsset, shouldSeniorAsset);

        uint shouldRatio = rdiv(seniorAsset, safeAdd(shouldNewReserve, model_.NAV));
        uint currSeniorRatio = assessor.calcSeniorRatio(shouldSeniorAsset, model_.NAV, shouldNewReserve);

        assertEq(currSeniorRatio, shouldRatio);
        assertEq(assessor.values_uint("changeBorrowAmountEpoch"), shouldNewReserve);

      //  assertEq(assessor.values_uint("updateSenior_seniorDebt"), rmul(model_.NAV, currSeniorRatio));
    }

    function testCalcSeniorState() public {
        LenderModel memory model = getDefaultModel();
        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        uint currSeniorAsset = 0;
        uint seniorRedeem = 0;
        uint seniorSupply = 0;

        uint seniorAsset = assessor.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, model.reserve, model.NAV);

        assertEq(seniorAsset, 0);

        // seniorSupply > seniorRedeem
        // delta + 10
         currSeniorAsset = 200 ether;

         seniorRedeem = 20 ether;
         seniorSupply = 30 ether;

        uint newReserve = coordinator.calcNewReserve(seniorRedeem, 0, seniorSupply, 0);

        seniorAsset = assessor.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, newReserve, model.NAV);
        assertEq(seniorAsset, 210 ether);

        // seniorSupply < seniorRedeem
        // delta  -10
        currSeniorAsset = 200 ether;

        seniorRedeem = 30 ether;
        seniorSupply = 20 ether;


         newReserve = coordinator.calcNewReserve(seniorRedeem, 0, seniorSupply, 0);
        seniorAsset = assessor.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, newReserve, model.NAV);
        assertEq(seniorAsset, 190 ether);

        // seniorSupply < seniorRedeem
        // delta higher than seniorBalance

        seniorRedeem = 120 ether;
        seniorSupply = 10 ether;

        newReserve = coordinator.calcNewReserve(seniorRedeem, 0, seniorSupply, 0);
        seniorAsset = assessor.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, newReserve, model.NAV);
        assertEq(seniorAsset, 90 ether);
    }
}

