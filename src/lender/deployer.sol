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

import {FixedPoint}      from "./fixed_point.sol";

// todo needs to be removed
import { Distributor } from "../test/simple/distributor.sol";

interface DependLike {
    function depend(bytes32, address) external;
}

interface AuthLike {
    function rely(address) external;
    function deny(address) external;
}

contract LenderDeployer is FixedPoint {
    address public root;
    address public currency;

    // factory contracts
    TrancheFab          public trancheFab;
    ReserveFab          public reserveFab;
    AssessorFab         public assessorFab;
    CoordinatorFab      public coordinatorFab;


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
    address             public reserve;
    address             public coordinator;

    // token names
    string              public seniorName;
    string              public seniorSymbol;
    string              public juniorName;
    string              public juniorSymbol;

    constructor(address root_, address currency_, TrancheFab trancheFab_, ReserveFab reserveFab_, AssessorFab assessorFab_, CoordinatorFab coordinatorFab_,
                uint minSeniorRatio_, uint maxSeniorRatio_, uint maxReserve_, uint challengeTime_, uint seniorInterestRate_,
                string memory seniorName_, string memory seniorSymbol_, string memory juniorName_, string memory juniorSymbol_) public {

        root = root_;
        trancheFab = trancheFab_;
        reserveFab = reserveFab_;
        assessorFab = assessorFab_;
        coordinatorFab = coordinatorFab_;

        // lender state variables
        minSeniorRatio = Fixed27(minSeniorRatio_);
        maxSeniorRatio = Fixed27(maxSeniorRatio_);
        maxReserve = maxReserve_;
        challengeTime = challengeTime_;
        seniorInterestRate = Fixed27(seniorInterestRate_);

        // token names
        seniorName = seniorName_;
        seniorSymbol = seniorSymbol_;
        juniorName = juniorName_;
        juniorSymbol =juniorSymbol_;
    }

    function deployTranches() public {
        require(seniorTranche == address(0));
        // todo check for gas maximum otherwise split into two methods
        seniorTranche = trancheFab.newTranche(currency,seniorName, seniorSymbol);
        juniorTranche = trancheFab.newTranche(currency, juniorName, juniorSymbol);

        AuthLike(seniorTranche).rely(root);
        AuthLike(juniorTranche).rely(root);
    }

    function deployReserve() public {
        require(reserve == address(0));
        reserve = reserveFab.newReserve(currency);
        AuthLike(reserve).rely(root);
    }

    function deployAssessor() public {
        require(assessor == address(0));
        assessor = assessorFab.newAssessor();
        AuthLike(assessor).rely(root);
    }

    function deployCoordinator() public {
        require(coordinator == address(0));
        coordinator = coordinatorFab.newCoordinator(challengeTime);
        AuthLike(coordinator).rely(root);
    }

    function deploy() public {
        require(coordinator != address(0) && assessor != address(0) &&
                reserve != address(0) && seniorTranche != address(0));

        // required depends
        // reserve
        DependLike(reserve).depend("assessor", assessor);

        // tranches
        DependLike(seniorTranche).depend("ticker", coordinator);
        DependLike(seniorTranche).depend("reserve",reserve);

        DependLike(juniorTranche).depend("ticker", coordinator);
        DependLike(juniorTranche).depend("reserve",reserve);

        // coordinator
        DependLike(coordinator).depend("reserve", reserve);
        DependLike(coordinator).depend("seniorTranche", seniorTranche);
        DependLike(coordinator).depend("juniorTranche", juniorTranche);
        DependLike(coordinator).depend("assessor", assessor);


        // required auth
        AuthLike(reserve).rely(assessor);

        AuthLike(seniorTranche).rely(coordinator);
        AuthLike(juniorTranche).rely(coordinator);
        AuthLike(assessor).rely(coordinator);
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
