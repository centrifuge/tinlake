// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./coordinator-base.t.sol";

contract CoordinatorValidateTest is CoordinatorTest {
    struct ValidateErr {
        int CURRENCY_AVAILABLE;
        int MAX_RESERVE;
        int MAX_ORDER;
        int MIN_SENIOR_RATIO;
        int MAX_SENIOR_RATIO;
    }

    ValidateErr public validateErr;
    int public successful;

    function setUp() public override {
        super.setUp();
        validateErr = ValidateErr({
            CURRENCY_AVAILABLE: -1,
            MAX_ORDER: -2,
            MAX_RESERVE: -3,
            MIN_SENIOR_RATIO: -4,
            MAX_SENIOR_RATIO: -5
            });
        successful = 0;
    }

    function cleanUpTestCase() public {
        if(coordinator.submissionPeriod() == true) {
            int status = coordinator.submitSolution(0,0,0,0);
            assertEq(status, coordinator.SUCCESS());
            hevm.warp(block.timestamp + 1 days);
            coordinator.executeEpoch();
        }
    }

    function executeTestCase(LenderModel memory model, ModelInput memory input, TestCaseDesc memory tCase) public {
        initTestConfig(model);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();

        int result = coordinator.validate(input.seniorRedeem, input.juniorRedeem, input.seniorSupply, input.juniorSupply);

        if (tCase.status != result) {
            emit log_named_int(string(abi.encodePacked(tCase.name)), result);
        }

        assertTrue(tCase.status == result);

      // execute epoch to clean up state
        cleanUpTestCase();
    }

    function testBasicValidate() public {
        LenderModel memory model = getDefaultModel();

        // case 1: simple happy case
        executeTestCase(model,
            ModelInput({
            seniorSupply : 10 ether,
            juniorSupply : 10 ether,
            seniorRedeem : 10 ether,
            juniorRedeem : 10 ether

        }), TestCaseDesc({name: "simple happy case", status: successful}));

        // case 2: edge case orders
        executeTestCase(model,
            ModelInput({
            seniorSupply : 100 ether,
            juniorSupply : 100 ether,
            seniorRedeem : 100 ether,
            juniorRedeem : 100 ether

            }), TestCaseDesc({name: "order edge cases", status: successful}));

        // case 3: seniorSupply too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 101 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "seniorSupply too high",status: validateErr.MAX_ORDER}));

        // case 3: juniorSupply too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 101 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "juniorSupply too high", status: validateErr.MAX_ORDER}));

        // case 3: seniorRedeem too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 101 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "seniorRedeem too high", status: validateErr.MAX_ORDER}));

        // case 4: juniorRedeem too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 101 ether

            }), TestCaseDesc({name: "juniorRedeem too high", status: validateErr.MAX_ORDER}));
    }

    function testCurrencyAvailable() public {
        LenderModel memory model = getDefaultModel();
        model.seniorRedeemOrder = 1000 ether;
        model.reserve = 100 ether;
        model.NAV = 900 ether;

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 101 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "not enough currency available", status: validateErr.CURRENCY_AVAILABLE}));


        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 51 ether,
            juniorRedeem : 50 ether

            }), TestCaseDesc({name: "not enough currency two redeems", status: validateErr.CURRENCY_AVAILABLE}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 50 ether,
            juniorRedeem : 50 ether

            }), TestCaseDesc({name: "not enough currency edge case", status: successful}));
    }

    function testMaxReserve() public {
        LenderModel memory model = getDefaultModel();
        model.maxReserve = 210 ether;

        executeTestCase(model,
            ModelInput({
            seniorSupply : 10 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "max reserve edge case", status: successful}));


        executeTestCase(model,
            ModelInput({
            seniorSupply : 11 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "reserve > maxReserve", status: validateErr.MAX_RESERVE}));

    }

    function testSeniorRatioTooHigh() public {
        LenderModel memory model = getDefaultModel();
        model.seniorSupplyOrder = 1000 ether;

        executeTestCase(model,
            ModelInput({
            seniorSupply : 1000 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "senior ratio too high", status: validateErr.MAX_SENIOR_RATIO}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 333 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "senior ratio not to high", status: successful}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 334 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "senior ratio too high edge", status: validateErr.MAX_SENIOR_RATIO}));
    }

    function testSeniorRatioTooLow() public {
        LenderModel memory model = getDefaultModel();
        model.juniorSupplyOrder = 1000 ether;

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 1000 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "senior ratio too low", status: validateErr.MIN_SENIOR_RATIO}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 50 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "junior ratio not too low", status: successful}));


        // edge case
        /*
        NAV + Reserve = 1000
        seniorDebt  + seniorBalance = 800
        minSeniorRatio = 0.75

        NAV + Reserve + juniorSupply * seniorMinRatio =  seniorDebt  + seniorBalance

        juniorSupply * seniorMinRatio = seniorDebt + seniorBalance - minRatio(NAV + Reserve) // *(1/minSeniorRatio)

        juniorSupply = (seniorDebt + seniorBalance - minRatio(NAV + Reserve))*(1/minSeniorRatio)

        juniorSupply = (800 - 0.75 * 1000) * 1/0.75
        */

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 66 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "junior ratio edge case in range", status: successful}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 67 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "junior ratio edge case too high", status: validateErr.MIN_SENIOR_RATIO}));
    }

    function testPoolClosing() public {
        LenderModel memory model = getDefaultModel();
        ModelInput memory input =  ModelInput({
            seniorSupply : 10 ether,
            juniorSupply : 10 ether,
            seniorRedeem : 10 ether,
            juniorRedeem : 0 ether

            });
        model.seniorDebt = 10000 ether;

        initTestConfig(model);
        assessor.setReturn("calcJuniorTokenPrice", 0);

        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == true);

        int result = coordinator.validate(input.seniorRedeem, input.juniorRedeem, input.seniorSupply, input.juniorSupply);
        assertEq(result, coordinator.ERR_POOL_CLOSING());
        assertTrue(coordinator.poolClosing() == true);

        input = ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 100 ether,
            juniorRedeem : 0 ether

            });

        // senior redeem should be allowed
        result = coordinator.validate(input.seniorRedeem, input.juniorRedeem, input.seniorSupply, input.juniorSupply);
        assertEq(result, coordinator.SUCCESS());

        // junior redeem will fail because the max Order for juniorRedeem is 0 because of a tokenPrice of 0
        input.juniorRedeem = 10 ether;
        result = coordinator.validate(input.seniorRedeem, input.juniorRedeem, input.seniorSupply, input.juniorSupply);
        assertEq(result, coordinator.ERR_MAX_ORDER());
    }

    function testPoolClosingWithSupply() public {
        LenderModel memory model = getDefaultModel();
        ModelInput memory input =  ModelInput({
            seniorSupply : 10 ether,
            juniorSupply : 10 ether,
            seniorRedeem : 10 ether,
            juniorRedeem : 0 ether

            });
        model.seniorDebt = 10000 ether;

        initTestConfig(model);
        assessor.setReturn("calcJuniorTokenPrice", 0);

        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
        assertTrue(coordinator.submissionPeriod() == true);

        int result = coordinator.submitSolution(input.seniorRedeem, input.juniorRedeem, input.seniorSupply, input.juniorSupply);
        assertEq(result, coordinator.ERR_POOL_CLOSING());
    }
}