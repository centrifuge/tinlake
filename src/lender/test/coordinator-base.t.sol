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
import "./mock/epoch-tranche.sol";
import "./mock/reserve.sol";
import "./mock/assessor.sol";
import "../deployer.sol";

contract Hevm {
    function warp(uint256) public;
}

contract CoordinatorTest is DSTest, Math {
    Hevm hevm;
    EpochCoordinator coordinator;

    EpochTrancheMock seniorTranche;
    EpochTrancheMock juniorTranche;

    AssessorMock assessor;

    ReserveMock reserve;

    address seniorTranche_;
    address juniorTranche_;
    address reserve_;
    address assessor_;

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

    struct TestCaseDesc {
        int status;
        bytes32 name;
    }

    LenderModel public model;

    function setUp() public {
        seniorTranche = new EpochTrancheMock();
        juniorTranche = new EpochTrancheMock();
        reserve = new ReserveMock();
        assessor = new AssessorMock();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);
        reserve_ = address(reserve);
        assessor_ = address(assessor);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        coordinator = new EpochCoordinator();
        coordinator.depend("juniorTranche", juniorTranche_);
        coordinator.depend("seniorTranche", seniorTranche_);
        coordinator.depend("reserve", reserve_);
        coordinator.depend("assessor", assessor_);

        model = getNoOrderModel();
        initTestConfig(model);

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

    function consoleLog(LenderModel memory model) internal {
        emit log_named_uint("maxReserve", model.maxReserve);
        emit log_named_uint("NAV", model.NAV);
        emit log_named_uint("reserve", model.reserve);
        emit log_named_uint("seniorDebt", model.seniorDebt);
    }

    function initTestConfig(LenderModel memory model) internal {
        assessor.setReturn("maxReserve", model.maxReserve);
        assessor.setReturn("calcJuniorTokenPrice", ONE);
        assessor.setReturn("calcSeniorTokenPrice", ONE);
        assessor.setReturn("calcNAV", model.NAV);
        reserve.setReturn("balance", model.reserve);
        assessor.setReturn("seniorDebt", model.seniorDebt);
        assessor.setReturn("seniorBalance", model.seniorBalance);
        assessor.setReturn("minSeniorRatio", model.minSeniorRatio);
        assessor.setReturn("maxSeniorRatio", model.maxSeniorRatio);

        juniorTranche.setEpochReturn(model.juniorSupplyOrder, model.juniorRedeemOrder);
        seniorTranche.setEpochReturn(model.seniorSupplyOrder, model.seniorRedeemOrder);
    }

    function calcNextEpochIn() public view returns(uint) {
        return 1 days - (now - coordinator.normalizeTimestamp(now));
    }
}

