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
import "tinlake-auth/auth.sol";

pragma solidity >=0.5.12;

// lender contracts
import {Assessor} from "./assessor.sol";
import {AllowanceOperator} from "./tranche/operator/allowance.sol";
import {WhitelistOperator} from "./tranche/operator/whitelist.sol";
import {Tranche} from "./tranche/tranche.sol";
import {SeniorTranche} from "./tranche/senior_tranche.sol";
import {SwitchableDistributor} from "./distributor/switchable.sol";

contract TrancheFab {
    function newTranche(address currency, address token) public returns (Tranche tranche) {
        tranche = new Tranche(currency, token);
        tranche.rely(msg.sender);
        tranche.deny(address(this));
    }
}

contract SeniorFab {
    function newSeniorTranche(address currency, address token) public returns (SeniorTranche tranche) {
        tranche = new SeniorTranche(currency, token);
        tranche.rely(msg.sender);
        tranche.deny(address(this));
    }
}

contract AssessorFab {
    function newAssessor() public returns (Assessor assessor) {
        assessor = new Assessor();
        assessor.rely(msg.sender);
        assessor.deny(address(this));
    }
}


// Operator Fabs
contract OperatorFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address);
}
contract AllowanceFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address operator) {
        AllowanceOperator operator = new AllowanceOperator(tranche, assessor, distributor);
        operator.rely(msg.sender);
        operator.deny(address(this));
    }
}

contract WhitelistFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address operator) {
        WhitelistOperator operator = new WhitelistOperator(tranche, assessor, distributor);
        operator.rely(msg.sender);
        operator.deny(address(this));
        return address(operator);
    }
}

// Distributor Fabs
contract DistributorFab {
    function newDistributor(address currency) public returns (address);
}

contract SwitchableDistributorFab {
    function newDistributor(address currency) public returns (address) {
        SwitchableDistributor distributor = new SwitchableDistributor(currency);

        distributor.rely(msg.sender);
        distributor.deny(address(this));
        return address(distributor);
    }
}

contract DistributorLike {
    function rely(address usr) public;
    function deny(address usr) public;
    function depend (bytes32 what, address addr) public;
    function balance() public;
}

contract OperatorLike {
    function rely(address usr) public;
    function deny(address usr) public;
}

// Simple Lender only deploys a SimpleDistributor as lender module

contract LenderDeployer is Auth {
    address rootAdmin;
    address deployUser;

    // Fabs
    TrancheFab trancheFab;
    SeniorFab seniorFab;
    AssessorFab assessorFab;
    DistributorFab distributorFab;
    OperatorFab operatorFab;

    // Contracts
    Tranche public tranche;
    SeniorTranche public senior;
    Assessor public assessor;
    DistributorLike public distributor;
    OperatorLike public operator;

    constructor(address rootAdmin_, address trancheFab_, address assessorFab_,
        address operatorFab_, address distributorFab_) public {

        deployUser = msg.sender;
        rootAdmin = rootAdmin_;

        wards[deployUser] = 1;
        wards[rootAdmin] = 1;

        trancheFab = TrancheFab(trancheFab_);
        assessorFab = AssessorFab(assessorFab_);
        operatorFab = OperatorFab(operatorFab_);

        distributorFab = DistributorFab(distributorFab_);
    }

    function depend(bytes32 what, address addr) public auth {
        if(what == "senior_fab") { seniorFab = SeniorFab(addr); }
        else revert();
    }

    function deployDistributor(address currency_) public auth {
        distributor = DistributorLike(distributorFab.newDistributor(currency_));

    }

    function deployTranche(address currency, address token) public auth {
        tranche = trancheFab.newTranche(currency, token);
        tranche.rely(rootAdmin);
    }

    function deployAssessor() public auth {
        assessor = assessorFab.newAssessor();
        assessor.rely(rootAdmin);
    }

    function deployOperator(address tranche, address assessor, address distributor) public auth {
        operator = OperatorLike(operatorFab.newOperator(tranche, assessor, distributor));
        operator.rely(rootAdmin);
    }

    function deploy() public auth {
        distributor.rely(rootAdmin);

        tranche.rely(address(operator));
        tranche.rely(address(distributor));

        distributor.depend("junior", address(tranche));
        //distributor also needs to depend on shelf

        // remove access of deployUser
        deny(deployUser);
    }
}