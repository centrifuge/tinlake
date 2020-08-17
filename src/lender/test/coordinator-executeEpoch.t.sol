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

        int result = coordinator.submitSolution(input.seniorRedeem, input.juniorRedeem, input.seniorSupply, input.juniorSupply);
        assertEq(result, submitSolutionReturn.NEW_BEST);

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

    function testSimpleExecute() public {
        LenderModel memory model_ = getDefaultModel();
        model_.seniorSupplyOrder = 300000 ether;

        ModelInput memory input =   ModelInput({
            seniorSupply : 10 ether,
            juniorSupply : 10 ether,
            seniorRedeem : 10 ether,
            juniorRedeem : 10 ether

            });

        prepareExecute(model_, input);

        uint lastEpochExecuted = coordinator.lastEpochExecuted();
        coordinator.executeEpoch();

        assertEq(coordinator.lastEpochExecuted(), lastEpochExecuted+1);
        assertTrue(coordinator.submissionPeriod() == false);
        assertEq(coordinator.minChallengePeriodEnd(), 0);
        assertEq(coordinator.bestSubScore(), 0);

        checkTrancheUpdates(model_, input);
    }
}

