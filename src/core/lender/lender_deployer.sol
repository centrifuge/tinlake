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

contract LenderDeployer is Auth {
    TrancheFab tranchefab;
    SeniorFab seniorfab;
    AssessorFab assessorfab;
    AllowanceFab allowancefab;
    WhitelistFab whitelistfab;
    SwitchableDistributorFab switchablefab;

    address mainDeployer;

    Tranche public tranche;
    SeniorTranche public senior;
    Assessor public assessor;
    AllowanceOperator public allowance;
    WhitelistOperator public whitelist;
    SwitchableDistributor public distributor;

    constructor(address mainDeployer_, TrancheFab trancheFab_, SeniorFab seniorFab_, AssessorFab assessorFab_, AllowanceFab allowanceFab_,
    WhitelistFab whitelistFab_, SwitchableDistributorFab switchableFab_) public {
        mainDeployer = mainDeployer_;
        tranchefab = trancheFab_;
        seniorfab = seniorFab_;
        assessorfab = assessorFab_;
        allowancefab = allowanceFab_;
        whitelistfab = whitelistFab_;
        switchablefab = switchableFab_;
    }

    function deployTranche(address currency, address token) public auth {
        tranche = tranchefab.newTranche(currency, token);
        tranche.rely(mainDeployer);
    }

    function deployAssessor() public auth {
        assessor = assessorfab.newAssessor();
        assessor.rely(mainDeployer);
    }

    function deployWhitelistOperator(address tranche, address assessor, address distributor) public auth {
        whitelist = whitelistfab.newOperator(tranche, assessor, distributor);
        whitelist.rely(mainDeployer);
    }

    function deployAllowanceOperator(address tranche, address assessor, address distributor) public auth {
        allowance = allowancefab.newOperator(tranche, assessor, distributor);
        allowance.rely(mainDeployer);
    }

    function deployDistributor(address currency) public auth {
        distributor = switchablefab.newDistributor(currency);
        distributor.rely(mainDeployer);
    }

    // only default deployment setup for now
    function deployDefaultLenderDeployment(address currency, address token) public auth {
        deployTranche(currency, token);
        deployDistributor(currency);
        deployWhitelistOperator(address(tranche), address(assessor), address(distributor));

        tranche.rely(address(whitelist));
        tranche.rely(address(distributor));

        distributor.depend("junior", address(tranche));
        //distributor also needs to depend on shelf

        removeDefaultDeployPermissions();
    }

    function removeDefaultDeployPermissions() public auth {
        tranche.deny(address(this));
        distributor.deny(address(this));
        assessor.deny(address(this));
        whitelist.deny(address(this));
    }
}
