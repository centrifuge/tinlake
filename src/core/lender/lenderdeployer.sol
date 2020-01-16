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
import {Assessor} from "./assessor.sol";
import {AllowanceOperator} from "./tranche/operator/allowance.sol";
import {WhitelistOperator} from "./tranche/operator/whitelist.sol";
import {Tranche} from "./tranche/tranche.sol";
import {SeniorTranche} from "./tranche/senior_tranche.sol";
import {Distributor} from "./distributor/switchable.sol";

contract TrancheFab {
    function newTranche(address currency, address token) public returns (Tranche tranche) {
        tranche = new Tranche(currency, token);
        tranche.rely(msg.sender);
        tranche.deny(address(this));
    }
}

contract SeniorTrancheFab {
    function newSeniorTranche(address currency, address token) public returns (SeniorTranche tranche) {
        tranche = new SeniorTranche(currency, token);
        tranche.rely(msg.sender);
        tranche.deny(address(this));
    }
}

contract AssessorFab {
    function newAssessor(address pile) public returns (Assessor assessor) {
        assessor = new Assessor(pile);
        assessor.rely(msg.sender);
        assessor.deny(address(this));
    }
}

contract AllowanceOperatorFab {
    function newAllowanceOperator(address tranche, address assessor) public returns (AllowanceOperator operator) {
        operator = new AllowanceOperator(tranche, assessor);
        operator.rely(msg.sender);
        operator.deny(address(this));
    }
}

contract WhitelistOperatorFab {
    function newWhitelistOperator(address tranche, address assessor) public returns (WhitelistOperator operator) {
        operator = new WhitelistOperator(tranche, assessor);
        operator.rely(msg.sender);
        operator.deny(address(this));
    }
}

contract DistributorFab {
    function newDistributorFab() public returns (Distributor distributor) {
        distributor = new Distributor();
        distributor.rely(msg.sender);
        distributor.deny(address(this));
    }
}

contract LenderDeployer {
    TrancheFab tranchefab;
    AssessorFab assessorfab;
    AllowanceOperatorFab allowanceoperatorfab;

}
