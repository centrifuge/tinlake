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

contract BaseTypes {
    struct Order {
        uint  seniorRedeem;
        uint  juniorRedeem;
        uint  juniorSupply;
        uint  seniorSupply;
    }
}

contract CoordinatorLike is BaseTypes {
    function bestSubmission() public returns (Order memory);
}

contract CoordinatorSubmitEpochTest is CoordinatorTest, BaseTypes {
    function setUp() public {
        super.setUp();
    }

    function submitSolution(ModelInput memory solution) internal {
        coordinator.submitSolution(solution.seniorRedeem, solution.juniorRedeem,
            solution.juniorSupply, solution.seniorSupply);
    }

    function compareWithBest(ModelInput memory model) internal {
        Order memory bestSubmission = CoordinatorLike(address(coordinator)).bestSubmission();
        assertEq(bestSubmission.seniorRedeem, model.seniorRedeem);
        assertEq(bestSubmission.juniorRedeem, model.juniorRedeem);
        assertEq(bestSubmission.seniorSupply, model.seniorSupply);
        assertEq(bestSubmission.juniorSupply, model.juniorSupply);
    }

    function testFailNoSubmission() public {
        coordinator.submitSolution(10 ether, 10 ether, 10 ether, 10 ether);
    }

    function testFailNoSubmissionLongTime() public {
        hevm.warp(now + 20 days);
        coordinator.submitSolution(10 ether, 10 ether, 10 ether, 10 ether);
    }


    function testFailNoSubmissionRequired() public {
        LenderModel memory model = getDefaultModel();
        initTestConfig(model);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();
        coordinator.submitSolution(10 ether, 10 ether, 10 ether, 10 ether);
    }

    function testSubmitSolution() public {
        LenderModel memory model = getDefaultModel();
        model.seniorSupplyOrder = 10000 ether;

        initTestConfig(model);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();

        ModelInput memory solution = ModelInput({
        seniorSupply : 1 ether,
        juniorSupply : 2 ether,
        seniorRedeem : 3 ether,
        juniorRedeem : 4 ether
        });

        submitSolution(solution);
        compareWithBest(solution);

        // challenge period started
        uint challengeEnd = now + 1 hours;
        assertEq(coordinator.minChallengePeriodEnd(), challengeEnd);


        hevm.warp(now + 2 hours);

        ModelInput memory betterSolution = ModelInput({
        seniorSupply : 2 ether,
        juniorSupply : 3 ether,
        seniorRedeem : 4 ether,
        juniorRedeem : 5 ether
        });

        submitSolution(betterSolution);

        // better solution should be new best
        compareWithBest(betterSolution);

        // no new challenge end
        assertEq(coordinator.minChallengePeriodEnd(), challengeEnd);

        hevm.warp(now + 2 hours);

        // re submit solution with lower score
        submitSolution(solution);

        // better solution should be still the best
        compareWithBest(betterSolution);

        // re submit solution with lower score
        solution.seniorSupply = 2 ether;
        submitSolution(solution);

        // better solution should be still the best
        compareWithBest(betterSolution);
    }
}

