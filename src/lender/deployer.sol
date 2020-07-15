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

import { AllowanceOperatorFab } from "./fabs/allowance_operator.sol";
import { DefaultAssessorFab } from "./fabs/default_assessor.sol";
import { DefaultDistributorFab } from "./fabs/default_distributor.sol";
import { FullInvestmentAssessorFab } from "./fabs/full_investment_assessor.sol";
import { ProportionalOperatorFab } from "./fabs/proportional_operator.sol";
import { SeniorTrancheFab } from "./fabs/senior_tranche.sol";
import { TrancheFab } from "./fabs/tranche.sol";
import { WhitelistOperatorFab } from "./fabs/whitelist_operator.sol";

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
}

contract DependLike {
    function depend(bytes32, address) public;
}
// abstract assessor fab
contract AssessorFab {
    function newAssessor(uint tokenAmountForONE) public returns (address);
}

// abstract operator fab
contract OperatorFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address);
}

// abstract distributor fab
contract DistributorFab {
    function newDistributor(address currency) public returns (address);
}


contract LenderDeployer {
    address root;

    // Fabs
    TrancheFab public        juniorTrancheFab;
    SeniorTrancheFab public  seniorTrancheFab;
    AssessorFab public       assessorFab;
    DistributorFab public    distributorFab;

    OperatorFab public       juniorOperatorFab;
    OperatorFab public       seniorOperatorFab;

    address public currency;
    uint public tokenAmountForONE;

    // Contracts
    address public assessor;
    address public distributor;

    // junior
    address public junior;
    address public juniorOperator;
    string public juniorTokenName;
    string public juniorTokenSymbol;

    // optional senior
    bool seniorActive;
    address public senior;
    address public seniorOperator;
    uint public seniorRate;
    string public seniorTokenName;
    string public seniorTokenSymbol;

    address constant ZERO = address(0);

    address public deployUsr;


    constructor(
      address root_,
      address currency_,
      uint tokenAmountForONE_,
      string memory juniorTokenName_,
      string memory juniorTokenSymbol_,
      address juniorTrancheFab_,
      address assessorFab_,
      address juniorOperatorFab_,
      address distributorFab_,
        bool seniorActive_
    ) public {
        deployUsr = msg.sender;
        root = root_;

        currency = currency_;
        tokenAmountForONE = tokenAmountForONE_;
        juniorTokenName = juniorTokenName_;
        juniorTokenSymbol = juniorTokenSymbol_;
        seniorActive = seniorActive_;


        assessorFab = AssessorFab(assessorFab_);
        juniorTrancheFab = TrancheFab(juniorTrancheFab_);
        juniorOperatorFab = OperatorFab(juniorOperatorFab_);
        distributorFab = DistributorFab(distributorFab_);
    }

    function initSenior(uint seniorRate_, string memory seniorTokenName_, string memory seniorTokenSymbol_, address seniorTrancheFab_, address seniorOperatorFab_) public {
        require(deployUsr == msg.sender && seniorActive);
        seniorRate = seniorRate_;
        seniorTokenName = seniorTokenName_;
        seniorTokenSymbol = seniorTokenSymbol_;
        seniorTrancheFab = SeniorTrancheFab(seniorTrancheFab_);
        seniorOperatorFab = OperatorFab(seniorOperatorFab_);
        deployUsr = address(0);
    }
    function deployDistributor() public {
        require(distributor == ZERO);
        distributor = distributorFab.newDistributor(currency);
        AuthLike(distributor).rely(root);
    }

    function deployAssessor() public {
        require(assessor == ZERO);
        assessor = assessorFab.newAssessor(tokenAmountForONE);
        AuthLike(assessor).rely(root);
    }

    function deployJuniorTranche() public {
        require(assessor != ZERO && junior == ZERO);
        junior = juniorTrancheFab.newTranche(currency, juniorTokenName, juniorTokenSymbol);
        AuthLike(junior).rely(root);
    }

    function deployJuniorOperator() public {
        require(junior != ZERO && distributor != ZERO);
        juniorOperator = juniorOperatorFab.newOperator(junior, assessor, distributor);
        AuthLike(juniorOperator).rely(root);
    }

    function deploySeniorTranche() public  {
        require(assessor != ZERO && senior == ZERO);
        senior = seniorTrancheFab.newTranche(currency, assessor, seniorRate, seniorTokenName, seniorTokenSymbol);
        AuthLike(senior).rely(root);
    }

    function deploySeniorOperator() public {
        require(senior != ZERO && distributor != ZERO);
        seniorOperator = seniorOperatorFab.newOperator(senior, assessor, distributor);
        AuthLike(seniorOperator).rely(root);
    }

    function deploy() public {
        // if juniorOperator and optionally seniorOperator are defined required deploy methods were called
        require(juniorOperator != ZERO && (address(seniorTrancheFab) == ZERO || seniorOperator != ZERO));

        AuthLike(junior).rely(juniorOperator);
        AuthLike(junior).rely(distributor);

        DependLike(distributor).depend("junior", junior);
        DependLike(assessor).depend("junior", junior);

        if (senior != ZERO) {
            AuthLike(senior).rely(seniorOperator);
            AuthLike(senior).rely(distributor);
            DependLike(distributor).depend("senior" , senior);
            DependLike(assessor).depend("senior" , senior);
        }
    }
}
