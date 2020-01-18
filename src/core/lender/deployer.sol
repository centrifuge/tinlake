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

contract AllowanceFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (AllowanceOperator operator) {
        operator = new AllowanceOperator(tranche, assessor, distributor);
        operator.rely(msg.sender);
        operator.deny(address(this));
    }
}

contract WhitelistFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (WhitelistOperator operator) {
        operator = new WhitelistOperator(tranche, assessor, distributor);
        operator.rely(msg.sender);
        operator.deny(address(this));
    }
}

contract SwitchableDistributorFab {
    function newDistributor(address currency) public returns (SwitchableDistributor distributor) {
        distributor = new SwitchableDistributor(currency);
        distributor.rely(msg.sender);
        distributor.deny(address(this));
    }
}



contract DistributorFab {
    // note: this is the mock distributor, which will interface with the lender/tranche side of Tinlake, and does not require auth for now.
    function newDistributor(address token_) public returns (SwitchableDistributor distributor) {
        distributor = new SwitchableDistributor(token_);
        distributor.rely(msg.sender);
        distributor.deny(address(this));
        return distributor;
    }
}

// Simple Lender only deploys a SimpleDistributor as lender module
contract LenderDeployer is Auth {
    address rootAdmin;
    address deployUser;

    TrancheFab tranchefab;
    SeniorFab seniorfab;
    AssessorFab assessorfab;
    AllowanceFab allowancefab;
    WhitelistFab whitelistfab;
    SwitchableDistributorFab distributorFab;

    Tranche public tranche;
    SeniorTranche public senior;
    Assessor public assessor;
    AllowanceOperator public allowance;
    WhitelistOperator public whitelist;
    SwitchableDistributor public distributor;


    constructor(address rootAdmin_, TrancheFab trancheFab_, SeniorFab seniorFab_, AssessorFab assessorFab_, AllowanceFab allowanceFab_,
        WhitelistFab whitelistFab_, SwitchableDistributorFab distributorFab_) public {

        deployUser = msg.sender;
        rootAdmin = rootAdmin_;

        wards[deployUser] = 1;
        wards[rootAdmin] = 1;

        tranchefab = trancheFab_;
        seniorfab = seniorFab_;
        assessorfab = assessorFab_;
        allowancefab = allowanceFab_;
        whitelistfab = whitelistFab_;
        distributorFab = distributorFab_;
    }

    function deployDistributor(address currency_) public auth {
        distributor = distributorFab.newDistributor(currency_);

    }

    function deployTranche(address currency, address token) public auth {
        tranche = tranchefab.newTranche(currency, token);
        tranche.rely(rootAdmin);
    }

    function deployAssessor() public auth {
        assessor = assessorfab.newAssessor();
        assessor.rely(rootAdmin);
    }

    function deployWhitelistOperator(address tranche, address assessor, address distributor) public auth {
        whitelist = whitelistfab.newOperator(tranche, assessor, distributor);
        whitelist.rely(rootAdmin);
    }

    function deployAllowanceOperator(address tranche, address assessor, address distributor) public auth {
        allowance = allowancefab.newOperator(tranche, assessor, distributor);
        allowance.rely(rootAdmin);
    }

    function deploy() public auth {
        distributor.rely(rootAdmin);

        tranche.rely(address(whitelist));
        tranche.rely(address(distributor));

        distributor.depend("junior", address(tranche));
        //distributor also needs to depend on shelf

        // remove access of deployUser
        deny(deployUser);
    }
}