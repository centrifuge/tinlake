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

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "./../coordinator.sol";
import "./mock/tranche.sol";
import "./mock/reserve.sol";
import "./mock/assessor.sol";
import "../deployer.sol";

contract Hevm {
    function warp(uint256) public;
}

// abstract
contract BaseTypes {
    struct Order {
        uint  seniorRedeem;
        uint  juniorRedeem;
        uint  juniorSupply;
        uint  seniorSupply;
    }

    struct LenderModel {
        uint maxReserve;
        uint reserve;
        uint maxSeniorRatio;
        uint minSeniorRatio;
        uint seniorDebt;
        uint seniorBalance;
        uint NAV;
        uint seniorRedeemOrder;
        uint seniorSupplyOrder;
        uint juniorSupplyOrder;
        uint juniorRedeemOrder;
    }

    struct ModelInput {
        uint seniorSupply;
        uint juniorSupply;
        uint seniorRedeem;
        uint juniorRedeem;
    }

    function submitSolution(address coordinator, ModelInput memory solution) internal returns(int) {
        return CoordinatorLike(coordinator).submitSolution(solution.seniorRedeem, solution.juniorRedeem,
            solution.juniorSupply, solution.seniorSupply);
    }
}

contract CoordinatorLike is BaseTypes {
    function bestSubmission() public returns (Order memory);
    function order() public returns (Order memory);
    function submitSolution(uint,uint,uint,uint) public returns (int);
}

contract CoordinatorTest is DSTest, Math, BaseTypes {
    Hevm hevm;
    EpochCoordinator coordinator;

    TrancheMock seniorTranche;
    TrancheMock juniorTranche;

    AssessorMock assessor;

    ReserveMock reserve;

    address seniorTranche_;
    address juniorTranche_;
    address reserve_;
    address assessor_;

    struct TestCaseDesc {
        int status;
        bytes32 name;
    }

    function setUp() public {
        seniorTranche = new TrancheMock();
        juniorTranche = new TrancheMock();
        reserve = new ReserveMock(address(0));
        assessor = new AssessorMock();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);
        reserve_ = address(reserve);
        assessor_ = address(assessor);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        uint challengeTime = 1 hours;
        coordinator = new EpochCoordinator(challengeTime);
        coordinator.depend("juniorTranche", juniorTranche_);
        coordinator.depend("seniorTranche", seniorTranche_);
        coordinator.depend("reserve", reserve_);
        coordinator.depend("assessor", assessor_);
        reserve.rely(address(coordinator));
        initTestConfig(getNoOrderModel());
    }

    function getNoOrderModel() internal returns (LenderModel memory) {
        return LenderModel({maxReserve: 10000 ether,
        reserve: 200 ether,
        maxSeniorRatio: 80 * 10 **25,
        minSeniorRatio: 75 * 10 **25,
        seniorDebt: 700 ether,
        seniorBalance: 100 ether,
        NAV: 800 ether,
        seniorRedeemOrder: 0,
        seniorSupplyOrder: 0,
        juniorSupplyOrder: 0,
        juniorRedeemOrder: 0});
    }

    function getDefaultModel()  internal returns (LenderModel memory)  {
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

    function consoleLog(LenderModel memory model_) internal {
        emit log_named_uint("maxReserve", model_.maxReserve);
        emit log_named_uint("NAV", model_.NAV);
        emit log_named_uint("reserve", model_.reserve);
        emit log_named_uint("seniorDebt", model_.seniorDebt);
    }

    function initTestConfig(LenderModel memory model_) internal {
        assessor.setReturn("maxReserve", model_.maxReserve);
        assessor.setReturn("calcJuniorTokenPrice", ONE);
        assessor.setReturn("calcSeniorTokenPrice", ONE);
        assessor.setReturn("calcUpdateNAV", model_.NAV);
        reserve.setReturn("balance", model_.reserve);
        assessor.setReturn("seniorDebt", model_.seniorDebt);
        assessor.setReturn("seniorBalance", model_.seniorBalance);
        assessor.setReturn("minSeniorRatio", model_.minSeniorRatio);
        assessor.setReturn("maxSeniorRatio", model_.maxSeniorRatio);

        juniorTranche.setEpochReturn(model_.juniorSupplyOrder, model_.juniorRedeemOrder);
        seniorTranche.setEpochReturn(model_.seniorSupplyOrder, model_.seniorRedeemOrder);
    }

    function calcNextEpochIn() public view returns(uint) {
        return (1 days) - (now - coordinator.lastEpochClosed());
    }

    function compareWithBest(ModelInput memory model_) internal {
        Order memory bestSubmission = CoordinatorLike(address(coordinator)).bestSubmission();
        assertEq(bestSubmission.seniorRedeem, model_.seniorRedeem);
        assertEq(bestSubmission.juniorRedeem, model_.juniorRedeem);
        assertEq(bestSubmission.seniorSupply, model_.seniorSupply);
        assertEq(bestSubmission.juniorSupply, model_.juniorSupply);
    }

    function submitSolution(ModelInput memory solution) internal returns(int) {
        return coordinator.submitSolution(solution.seniorRedeem, solution.juniorRedeem,
            solution.juniorSupply, solution.seniorSupply);
    }

    function calcNewSeniorRatio(LenderModel memory model, ModelInput memory input) public returns (uint) {
        uint currencyAvailable = model.reserve + input.seniorSupply + input.juniorSupply;
        uint currencyOut = input.seniorRedeem + input.juniorRedeem;

        uint seniorAsset = (model.seniorBalance + model.seniorDebt + input.seniorSupply) - input.seniorRedeem;

        return rdiv(seniorAsset, model.NAV + currencyAvailable-currencyOut);
    }
}

