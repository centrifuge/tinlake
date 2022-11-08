// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "tinlake-math/math.sol";

import "src/lender/coordinator.sol";
import "src/lender/definitions.sol";
import "./mock/tranche.sol";
import "./mock/reserve.sol";
import "./mock/assessor.sol";
import "src/lender/deployer.sol";

interface Hevm {
    function warp(uint256) external;
}

// abstract
contract BaseTypes {
    struct Order {
        uint256 seniorRedeem;
        uint256 juniorRedeem;
        uint256 juniorSupply;
        uint256 seniorSupply;
    }

    struct LenderModel {
        uint256 maxReserve;
        uint256 reserve;
        uint256 maxSeniorRatio;
        uint256 minSeniorRatio;
        uint256 seniorDebt;
        uint256 seniorBalance;
        uint256 NAV;
        uint256 seniorRedeemOrder;
        uint256 seniorSupplyOrder;
        uint256 juniorSupplyOrder;
        uint256 juniorRedeemOrder;
    }

    struct ModelInput {
        uint256 seniorSupply;
        uint256 juniorSupply;
        uint256 seniorRedeem;
        uint256 juniorRedeem;
    }

    function submitSolution(address coordinator, ModelInput memory solution) internal returns (int256) {
        return CoordinatorLike(coordinator).submitSolution(
            solution.seniorRedeem, solution.juniorRedeem, solution.juniorSupply, solution.seniorSupply
        );
    }
}

abstract contract CoordinatorLike is BaseTypes {
    function bestSubmission() public virtual returns (Order memory);
    function order() public virtual returns (Order memory);
    function submitSolution(uint256, uint256, uint256, uint256) public virtual returns (int256);
}

contract AssessorMockWithDef is AssessorMock, Definitions {}

contract CoordinatorTest is Test, Math, BaseTypes {
    Hevm hevm;
    EpochCoordinator coordinator;

    TrancheMock seniorTranche;
    TrancheMock juniorTranche;

    AssessorMockWithDef assessor;

    address seniorTranche_;
    address juniorTranche_;
    address assessor_;

    struct TestCaseDesc {
        int256 status;
        bytes32 name;
    }

    function setUp() public virtual {
        seniorTranche = new TrancheMock();
        juniorTranche = new TrancheMock();
        assessor = new AssessorMockWithDef();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);
        assessor_ = address(assessor);

        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);

        uint256 challengeTime = 1 hours;
        coordinator = new EpochCoordinator(challengeTime);
        coordinator.depend("juniorTranche", juniorTranche_);
        coordinator.depend("seniorTranche", seniorTranche_);
        coordinator.depend("assessor", assessor_);
        initTestConfig(getNoOrderModel());
    }

    function getNoOrderModel() internal pure returns (LenderModel memory) {
        return LenderModel({
            maxReserve: 10000 ether,
            reserve: 200 ether,
            maxSeniorRatio: 80 * 10 ** 25,
            minSeniorRatio: 75 * 10 ** 25,
            seniorDebt: 700 ether,
            seniorBalance: 100 ether,
            NAV: 800 ether,
            seniorRedeemOrder: 0,
            seniorSupplyOrder: 0,
            juniorSupplyOrder: 0,
            juniorRedeemOrder: 0
        });
    }

    function getDefaultModel() internal pure returns (LenderModel memory) {
        return LenderModel({
            maxReserve: 10000 ether,
            reserve: 200 ether,
            maxSeniorRatio: 85 * 10 ** 25,
            minSeniorRatio: 75 * 10 ** 25,
            seniorDebt: 700 ether,
            seniorBalance: 100 ether,
            NAV: 800 ether,
            seniorRedeemOrder: 100 ether,
            seniorSupplyOrder: 100 ether,
            juniorSupplyOrder: 100 ether,
            juniorRedeemOrder: 100 ether
        });
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

    function calcNextEpochIn() public view returns (uint256) {
        return (coordinator.minimumEpochTime()) - (block.timestamp - coordinator.lastEpochClosed());
    }

    function compareWithBest(ModelInput memory model_) internal {
        Order memory bestSubmission = CoordinatorLike(address(coordinator)).bestSubmission();
        assertEq(bestSubmission.seniorRedeem, model_.seniorRedeem);
        assertEq(bestSubmission.juniorRedeem, model_.juniorRedeem);
        assertEq(bestSubmission.seniorSupply, model_.seniorSupply);
        assertEq(bestSubmission.juniorSupply, model_.juniorSupply);
    }

    function submitSolution(ModelInput memory solution) internal returns (int256) {
        return coordinator.submitSolution(
            solution.seniorRedeem, solution.juniorRedeem, solution.juniorSupply, solution.seniorSupply
        );
    }

    function calcNewSeniorRatio(LenderModel memory model, ModelInput memory input) public pure returns (uint256) {
        uint256 currencyAvailable = model.reserve + input.seniorSupply + input.juniorSupply;
        uint256 currencyOut = input.seniorRedeem + input.juniorRedeem;

        uint256 seniorAsset = (model.seniorBalance + model.seniorDebt + input.seniorSupply) - input.seniorRedeem;

        return rdiv(seniorAsset, model.NAV + currencyAvailable - currencyOut);
    }
}
