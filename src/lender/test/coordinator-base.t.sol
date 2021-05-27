// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "tinlake-math/math.sol";

import "./../coordinator.sol";
import "./../definitions.sol";
import "./mock/tranche.sol";
import "./mock/reserve.sol";
import "./mock/assessor.sol";
import "../deployer.sol";

interface Hevm {
    function warp(uint256) external;
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

abstract contract CoordinatorLike is BaseTypes {
    function bestSubmission() public virtual returns (Order memory);
    function order() public virtual returns (Order memory);
    function submitSolution(uint,uint,uint,uint) public virtual returns (int);
}

contract AssessorMockWithDef is AssessorMock, Definitions { }

contract CoordinatorTest is DSTest, Math, BaseTypes {
    Hevm hevm;
    EpochCoordinator coordinator;

    TrancheMock seniorTranche;
    TrancheMock juniorTranche;

    AssessorMockWithDef assessor;

    ReserveMock reserve;

    address seniorTranche_;
    address juniorTranche_;
    address reserve_;
    address assessor_;

    struct TestCaseDesc {
        int status;
        bytes32 name;
    }

    function setUp() public virtual {
        seniorTranche = new TrancheMock();
        juniorTranche = new TrancheMock();
        reserve = new ReserveMock(address(0));
        assessor = new AssessorMockWithDef();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);
        reserve_ = address(reserve);
        assessor_ = address(assessor);

        hevm = Hevm(HEVM_ADDRESS);
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

    function getNoOrderModel() internal pure returns (LenderModel memory) {
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

    function getDefaultModel()  internal pure returns (LenderModel memory)  {
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
        emit log_named_uint("reserve", model_.reserve);
        emit log_named_uint("seniorDebt", model_.seniorDebt);
    }

    function initTestConfig(LenderModel memory model_) internal {
        assessor.setReturn("maxReserve", model_.maxReserve);
        assessor.setReturn("calcJuniorTokenPrice", ONE);
        assessor.setReturn("calcSeniorTokenPrice", ONE);
        assessor.setReturn("calcUpdateNAV", model_.NAV);
        assessor.setReturn("balance", model_.reserve);
        assessor.setReturn("seniorDebt", model_.seniorDebt);
        assessor.setReturn("seniorBalance", model_.seniorBalance);
        assessor.setReturn("minSeniorRatio", model_.minSeniorRatio);
        assessor.setReturn("maxSeniorRatio", model_.maxSeniorRatio);

        juniorTranche.setEpochReturn(model_.juniorSupplyOrder, model_.juniorRedeemOrder);
        seniorTranche.setEpochReturn(model_.seniorSupplyOrder, model_.seniorRedeemOrder);
    }

    function calcNextEpochIn() public view returns(uint) {
        return (coordinator.minimumEpochTime()) - (block.timestamp - coordinator.lastEpochClosed());
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

    function calcNewSeniorRatio(LenderModel memory model, ModelInput memory input) public pure returns (uint) {
        uint currencyAvailable = model.reserve + input.seniorSupply + input.juniorSupply;
        uint currencyOut = input.seniorRedeem + input.juniorRedeem;

        uint seniorAsset = (model.seniorBalance + model.seniorDebt + input.seniorSupply) - input.seniorRedeem;

        return rdiv(seniorAsset, model.NAV + currencyAvailable-currencyOut);
    }
}
