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

contract CoordinatorValidateTest is CoordinatorTest {
    function setUp() public {
        super.setUp();
    }

    function executeTestCase(LenderModel memory model, ModelInput memory input, TestCaseDesc memory tCase) public {
        initTestConfig(model);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();

        bool result = coordinator.validate(input.seniorRedeem, input.juniorRedeem, input.seniorSupply, input.juniorSupply);

        if (tCase.successful != result) {
            emit log_named_int(tCase.name, -1);
        }

        assertTrue(tCase.successful == result);
    }

    function getDefaultModel()  public returns (LenderModel memory model)  {
        return LenderModel({
        maxReserve: 10000 ether,
        reserve: 200 ether,
        maxSeniorRatio: 85 * 10 **25,
        minSeniorRatio: 75 * 10 **25,
        seniorDebt: 700 ether,
        seniorBalance: 100 ether,
        NAV: 800 ether,
        seniorRedeemOrder: 100 ether,
        seniorSupplyOrder: 100 ether,
        juniorSupplyOrder: 100 ether,
        juniorRedeemOrder: 100 ether});
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

        }), TestCaseDesc({name: "simple happy case", successful: true}));

        // case 2: edge case orders
        executeTestCase(model,
            ModelInput({
            seniorSupply : 100 ether,
            juniorSupply : 100 ether,
            seniorRedeem : 100 ether,
            juniorRedeem : 100 ether

            }), TestCaseDesc({name: "order edge cases", successful: true}));

        // case 3: seniorSupply too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 101 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "seniorSupply too high",successful: false}));

        // case 3: juniorSupply too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 101 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "juniorSupply too high",successful: false}));

        // case 3: seniorRedeem too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 101 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "seniorRedeem too high",successful: false}));

        // case 4: juniorRedeem too high
        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 101 ether

            }), TestCaseDesc({name: "juniorRedeem too high",successful: false}));
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

            }), TestCaseDesc({name: "not enough currency available",successful: false}));


        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 51 ether,
            juniorRedeem : 50 ether

            }), TestCaseDesc({name: "not enough currency two redeems",successful: false}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 50 ether,
            juniorRedeem : 50 ether

            }), TestCaseDesc({name: "not enough currency edge case",successful: true}));
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

            }), TestCaseDesc({name: "max reserve edge case",successful: true}));


        executeTestCase(model,
            ModelInput({
            seniorSupply : 11 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "reserve > maxReserve", successful: false}));

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

            }), TestCaseDesc({name: "senior ratio too high" ,successful: false}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 333 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "senior ratio not to high" ,successful: true}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 334 ether,
            juniorSupply : 0 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "senior ratio too high edge" ,successful: false}));
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

            }), TestCaseDesc({name: "senior ratio too low" ,successful: false}));

        executeTestCase(model,
            ModelInput({
            seniorSupply : 0 ether,
            juniorSupply : 50 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether

            }), TestCaseDesc({name: "junior ratio not too low" ,successful: true}));

            // todo add edge case

    }

}

