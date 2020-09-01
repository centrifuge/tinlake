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

contract CoordinatorExecuteEpochTest is CoordinatorTest {

    struct SeniorState {
        uint seniorDebt;
        uint seniorBalance;
    }

    function setUp() public {
        super.setUp();
    }

    function prepareExecute(LenderModel memory model_, ModelInput memory input) public {
        initTestConfig(model_);
        hevm.warp(now + 1 days);
        assertTrue(coordinator.submissionPeriod() == false);
        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == true);

        seniorTranche.setEpochReturn(model_.seniorSupplyOrder, model_.seniorRedeemOrder);

        int result = coordinator.submitSolution(input.seniorRedeem, input.juniorRedeem, input.juniorSupply, input.seniorSupply);
        // new best solution
        assertEq(result, coordinator.SUCCESS());

        hevm.warp(now + 1 days);
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

        uint seniorAsset = coordinator.calcSeniorAssetValue(input.seniorRedeem, input.seniorSupply, safeAdd(model_.seniorDebt, model_.seniorBalance), shouldNewReserve, model_.NAV);

        // change or orders delta = -2 ether
        uint shouldSeniorAsset = safeSub(safeAdd(model_.seniorDebt, model_.seniorBalance), 2 ether);

        assertEq(seniorAsset, shouldSeniorAsset);

        uint shouldRatio = rdiv(seniorAsset, safeAdd(shouldNewReserve, model_.NAV));

        uint currSeniorRatio = coordinator.calcSeniorRatio(shouldSeniorAsset, model_.NAV, shouldNewReserve);

        assertEq(currSeniorRatio, shouldRatio);
        assertEq(reserve.values_uint("currency_available"), shouldNewReserve);

      //  assertEq(assessor.values_uint("updateSenior_seniorDebt"), rmul(model_.NAV, currSeniorRatio));
    }

    function testCalcSeniorRatio() public {
        uint seniorDebt = 300 ether;
        uint seniorBalance = 200 ether;
        uint NAV = 1000 ether;
        uint reserve = 1000 ether;

        assertEq(coordinator.calcAssets(NAV, reserve), 2000 ether);
        // ratio 25%
        assertEq(coordinator.calcSeniorRatio(safeAdd(seniorDebt,seniorBalance), NAV, reserve), 25 * 10**25);
        assertEq(coordinator.calcSeniorRatio(0, 0, 0), 0);
    }

    function testCalcSeniorState() public {
        LenderModel memory model = getDefaultModel();
        initTestConfig(model);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();

        uint currSeniorAsset = 0;
        uint seniorRedeem = 0;
        uint seniorSupply = 0;

        uint seniorAsset = coordinator.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, model.reserve, model.NAV);

        assertEq(seniorAsset, 0);

        // seniorSupply > seniorRedeem
        // delta + 10
         currSeniorAsset = 200 ether;

         seniorRedeem = 20 ether;
         seniorSupply = 30 ether;

        uint newReserve = coordinator.calcNewReserve(seniorRedeem, 0, seniorSupply, 0);

        seniorAsset = coordinator.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, newReserve, model.NAV);
        assertEq(seniorAsset, 210 ether);

        // seniorSupply < seniorRedeem
        // delta  -10
        currSeniorAsset = 200 ether;

        seniorRedeem = 30 ether;
        seniorSupply = 20 ether;


         newReserve = coordinator.calcNewReserve(seniorRedeem, 0, seniorSupply, 0);
        seniorAsset = coordinator.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, newReserve, model.NAV);
        assertEq(seniorAsset, 190 ether);

        // seniorSupply < seniorRedeem
        // delta higher than seniorBalance

        seniorRedeem = 120 ether;
        seniorSupply = 10 ether;

        newReserve = coordinator.calcNewReserve(seniorRedeem, 0, seniorSupply, 0);
        seniorAsset = coordinator.calcSeniorAssetValue(seniorRedeem, seniorSupply, currSeniorAsset, newReserve, model.NAV);
        assertEq(seniorAsset, 90 ether);
    }
}

