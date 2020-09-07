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

import {ReserveFab}     from "./fabs/reserve.sol";
import {AssessorFab}    from "./fabs/assessor.sol";
import {TrancheFab}     from "./fabs/tranche.sol";
import {CoordinatorFab} from "./fabs/coordinator.sol";
import {OperatorFab}    from "./fabs/operator.sol";

import {FixedPoint}      from "./../fixed_point.sol";

// todo needs to be removed
import { Distributor } from "../test/simple/distributor.sol";


interface DependLike {
    function depend(bytes32, address) external;
}

interface AuthLike {
    function rely(address) external;
    function deny(address) external;
}

interface MemberlistLike {
    function updateMember(address, uint) external;
}

interface FileLike {
    function file(bytes32 name, uint value) external;
}

contract LenderDeployer is FixedPoint {
    address public root;
    address public currency;

    // factory contracts
    TrancheFab          public trancheFab;
    ReserveFab          public reserveFab;
    AssessorFab         public assessorFab;
    CoordinatorFab      public coordinatorFab;
    OperatorFab         public operatorFab;

    // lender state variables
    Fixed27             public minSeniorRatio;
    Fixed27             public maxSeniorRatio;
    uint                public maxReserve;
    uint                public challengeTime;
    Fixed27             public seniorInterestRate;


    // contract addresses
    address             public assessor;
    address             public seniorTranche;
    address             public juniorTranche;
    address             public seniorOperator;
    address             public juniorOperator;
    address             public reserve;
    address             public coordinator;

    address             public seniorToken;
    address             public juniorToken;

    // token names
    string              public seniorName;
    string              public seniorSymbol;
    string              public juniorName;
    string              public juniorSymbol;
    // restricted token member list
    address             public seniorMemberlist;
    address             public juniorMemberlist;

    address             public deployer;

    constructor(address root_, address currency_, TrancheFab trancheFab_, ReserveFab reserveFab_, AssessorFab assessorFab_, CoordinatorFab coordinatorFab_, OperatorFab operatorFab_,
                string memory seniorName_, string memory seniorSymbol_, string memory juniorName_, string memory juniorSymbol_) public {

        deployer = msg.sender;
        root = root_;
        currency = currency_;

        trancheFab = trancheFab_;
        reserveFab = reserveFab_;
        assessorFab = assessorFab_;
        coordinatorFab = coordinatorFab_;
        operatorFab = operatorFab_;

        // token names
        seniorName = seniorName_;
        seniorSymbol = seniorSymbol_;
        juniorName = juniorName_;
        juniorSymbol =juniorSymbol_;
    }

    function init(uint minSeniorRatio_, uint maxSeniorRatio_, uint maxReserve_, uint challengeTime_, uint seniorInterestRate_) public {
        require(msg.sender == deployer);
        challengeTime = challengeTime_;
        minSeniorRatio = Fixed27(minSeniorRatio_);
        maxSeniorRatio = Fixed27(maxSeniorRatio_);
        maxReserve = maxReserve_;
        seniorInterestRate = Fixed27(seniorInterestRate_);

        deployer = address(1);
    }

    function deployJunior() public {
        require(juniorTranche == address(0) && deployer == address(1));
        (juniorTranche, juniorToken, juniorMemberlist) = trancheFab.newTranche(currency, juniorName, juniorSymbol);
        juniorOperator = operatorFab.newOperator(juniorTranche);
        AuthLike(juniorMemberlist).rely(root);
        AuthLike(juniorToken).rely(root);
        AuthLike(juniorOperator).rely(root);
        AuthLike(juniorTranche).rely(root);
    }

    function deploySenior() public {
        require(seniorTranche == address(0) && deployer == address(1));
        // todo check for gas maximum otherwise split into two methods
        (seniorTranche, seniorToken, seniorMemberlist) = trancheFab.newTranche(currency, seniorName, seniorSymbol);
        seniorOperator = operatorFab.newOperator(seniorTranche);
        AuthLike(seniorMemberlist).rely(root);
        AuthLike(seniorToken).rely(root);
        AuthLike(seniorOperator).rely(root);
        AuthLike(seniorTranche).rely(root);

    }

    function deployReserve() public {
        require(reserve == address(0) && deployer == address(1));
        reserve = reserveFab.newReserve(currency);
        AuthLike(reserve).rely(root);
    }

    function deployAssessor() public {
        require(assessor == address(0) && deployer == address(1));
        assessor = assessorFab.newAssessor();
        AuthLike(assessor).rely(root);
    }

    function deployCoordinator() public {
        require(coordinator == address(0) && deployer == address(1));
        coordinator = coordinatorFab.newCoordinator(challengeTime);
        AuthLike(coordinator).rely(root);
    }

    function deploy() public {
        require(coordinator != address(0) && assessor != address(0) &&
                reserve != address(0) && seniorTranche != address(0));

        // required depends
        // reserve
        DependLike(reserve).depend("assessor", assessor);
        AuthLike(reserve).rely(seniorTranche);
        AuthLike(reserve).rely(juniorTranche);
        AuthLike(reserve).rely(coordinator);
        AuthLike(reserve).rely(assessor);


        // tranches
        DependLike(seniorTranche).depend("reserve",reserve);
        DependLike(juniorTranche).depend("reserve",reserve);
        AuthLike(seniorTranche).rely(coordinator);
        AuthLike(juniorTranche).rely(coordinator);
        AuthLike(seniorTranche).rely(seniorOperator);
        AuthLike(juniorTranche).rely(juniorOperator);

        // coordinator implements epoch ticker interface
        DependLike(seniorTranche).depend("epochTicker", coordinator);
        DependLike(juniorTranche).depend("epochTicker", coordinator);

        //restricted token
        DependLike(seniorToken).depend("memberlist", seniorMemberlist);
        DependLike(juniorToken).depend("memberlist", juniorMemberlist);

        //allow tinlake contracts to hold drop/tin tokens
        MemberlistLike(juniorMemberlist).updateMember(juniorTranche, uint(-1));
        MemberlistLike(seniorMemberlist).updateMember(seniorTranche, uint(-1));

        // operator
        DependLike(seniorOperator).depend("tranche", seniorTranche);
        DependLike(juniorOperator).depend("tranche", juniorTranche);
        DependLike(seniorOperator).depend("token", seniorToken);
        DependLike(juniorOperator).depend("token", juniorToken);


        // coordinator
        DependLike(coordinator).depend("reserve", reserve);
        DependLike(coordinator).depend("seniorTranche", seniorTranche);
        DependLike(coordinator).depend("juniorTranche", juniorTranche);
        DependLike(coordinator).depend("assessor", assessor);

        // assessor
        DependLike(assessor).depend("seniorTranche", seniorTranche);
        DependLike(assessor).depend("juniorTranche", juniorTranche);

        AuthLike(assessor).rely(coordinator);
        AuthLike(assessor).rely(reserve);

        FileLike(assessor).file("seniorInterestRate", seniorInterestRate.value);
        FileLike(assessor).file("maxReserve", maxReserve);
        FileLike(assessor).file("maxSeniorRatio", maxSeniorRatio.value);
        FileLike(assessor).file("minSeniorRatio", minSeniorRatio.value);
    }

}

contract MockLenderDeployer {
    address public distributor_;
    Distributor public distributor;

    constructor(address root, address currency) public {
        distributor = new Distributor(currency);
        distributor_ = address(distributor);
        distributor.rely(root);
    }
}
