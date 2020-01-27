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
pragma solidity >=0.5.12;


// lender contracts
import { DefaultAssessor } from "./assessor/default.sol";
import { FullInvestmentAssessor } from "./assessor/full_investment.sol";
import { AllowanceOperator } from "./tranche/operator/allowance.sol";
import { WhitelistOperator } from "./tranche/operator/whitelist.sol";
import { Tranche } from "./tranche/tranche.sol";
import { SeniorTranche } from "./tranche/senior_tranche.sol";
import { DefaultDistributor } from "./distributor/default.sol";

import "tinlake-erc20/erc20.sol";

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
}

contract DependLike {
    function depend(bytes32, address) public;
}

contract TrancheFab {
    string constant public symbol = "TIN";
    string constant public name = "Tinlake TIN Token";

    function newTranche(address currency) public returns (address) {
        ERC20 token = new ERC20(symbol, name);
        Tranche tranche = new Tranche(address(token), currency);
        tranche.rely(msg.sender);
        tranche.deny(address(this));
        token.rely(address(tranche));
        return address(tranche);
    }
}

contract SeniorTrancheFab {
    string constant public symbol = "DROP";
    string constant public name = "Tinlake Drop Token";
    uint public ratePerSecond;

    constructor (uint rate_) public {
        ratePerSecond = rate_;
    }

    function newTranche(address currency, address assessor) public returns (address) {
        ERC20 token = new ERC20(symbol, name);
        SeniorTranche senior = new SeniorTranche(address(token), currency, assessor);
        senior.rely(msg.sender);
        senior.file("rate", ratePerSecond);
        senior.deny(address(this));
        token.rely(address(senior));
        return address(senior);
    }
}

contract AssessorFab {
    function newAssessor(uint tokenAmountForONE) public returns (address);
}

contract FullInvestmentAssessorFab {
    function newAssessor(uint tokenAmountForONE) public returns (address) {
        FullInvestmentAssessor assessor = new FullInvestmentAssessor(tokenAmountForONE);
        assessor.rely(msg.sender);
        assessor.deny(address(this));
        return address(assessor);
    }
}

contract DefaultAssessorFab {
    function newAssessor(uint tokenAmountForONE) public returns (address) {
        DefaultAssessor assessor = new DefaultAssessor(tokenAmountForONE);
        assessor.rely(msg.sender);
        assessor.deny(address(this));
        return address(assessor);
    }
}


// Operator Fabs

// abstract operator fab
contract OperatorFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address);
}

contract AllowanceOperatorFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address) {
        AllowanceOperator operator = new AllowanceOperator(tranche, assessor, distributor);
        operator.rely(msg.sender);
        operator.deny(address(this));
        return address(operator);
    }
}

contract WhitelistOperatorFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address) {
        WhitelistOperator operator = new WhitelistOperator(tranche, assessor, distributor);
        operator.rely(msg.sender);
        operator.deny(address(this));
        return address(operator);
    }
}

// Distributor Fabs
// abstract distributor fab
contract DistributorFab {
    function newDistributor(address currency) public returns (address);
}
contract DefaultDistributorFab {
    function newDistributor(address currency) public returns (address) {
        DefaultDistributor distributor = new DefaultDistributor(currency);
        distributor.rely(msg.sender);
        distributor.deny(address(this));
        return address(distributor);
    }
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

    // optional senior
    address public senior;
    address public seniorOperator;

    address constant ZERO = address(0);

    constructor(
      address root_,
      address currency_,
      uint tokenAmountForONE_,
      address juniorTrancheFab_,
      address assessorFab_,
      address juniorOperatorFab_,
      address distributorFab_,
      address seniorTrancheFab_,
      address seniorOperatorFab_
    ) public {
        root = root_;

        currency = currency_;
        tokenAmountForONE = tokenAmountForONE_;

        assessorFab = AssessorFab(assessorFab_);
        juniorTrancheFab = TrancheFab(juniorTrancheFab_);
        juniorOperatorFab = OperatorFab(juniorOperatorFab_);
        seniorTrancheFab = SeniorTrancheFab(seniorTrancheFab_);
        seniorOperatorFab = OperatorFab(seniorOperatorFab_);

        distributorFab = DistributorFab(distributorFab_);
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
        junior = juniorTrancheFab.newTranche(currency);
        AuthLike(junior).rely(root);
    }

    function deployJuniorOperator() public {
        require(junior != ZERO && distributor != ZERO);
        juniorOperator = juniorOperatorFab.newOperator(junior, assessor, distributor);
        AuthLike(juniorOperator).rely(root);
    }

    function deploySeniorTranche() public  {
        require(assessor != ZERO && senior == ZERO);
        senior = seniorTrancheFab.newTranche(currency, assessor);
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
