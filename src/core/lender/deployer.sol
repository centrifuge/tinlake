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
import {DefaultAssessor} from "./assessor/default.sol";
import {AllowanceOperator} from "./tranche/operator/allowance.sol";
import {WhitelistOperator} from "./tranche/operator/whitelist.sol";
import {Tranche} from "./tranche/tranche.sol";
import {SeniorTranche} from "./tranche/senior_tranche.sol";
import {SwitchableDistributor} from "./distributor/switchable.sol";
import {DefaultDistributor} from "./distributor/default.sol";
import "tinlake-erc20/erc20.sol";

contract TrancheFab {
    function newTranche(address currency, address token) public returns (Tranche tranche) {
        tranche = new Tranche(token, currency);
        tranche.rely(msg.sender);
        tranche.deny(address(this));
    }
}

contract SeniorTrancheFab {
    function newSeniorTranche(address currency, address token, address assessor) public returns (SeniorTranche tranche) {
        tranche = new SeniorTranche(currency, token, assessor);
        tranche.rely(msg.sender);
        tranche.deny(address(this));
    }
}


contract AssessorFab {
    function newAssessor() public returns (address);
}

contract DefaultAssessorFab {
    function newAssessor() public returns (address) {
        DefaultAssessor assessor = new DefaultAssessor();
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

contract OperatorLike {
    function rely(address usr) public;
    function deny(address usr) public;
}

contract AllowanceOperatorFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address operator_) {
        AllowanceOperator operator = new AllowanceOperator(tranche, assessor, distributor);
        operator.rely(msg.sender);
        operator.deny(address(this));
        return address(operator);
    }
}

contract WhitelistOperatorFab {
    function newOperator(address tranche, address assessor, address distributor) public returns (address operator_) {
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

contract DistributorLike {
    bool public borrowFromTranches;
    function rely(address usr) public;
    function deny(address usr) public;
    function depend (bytes32 what, address addr) public;
    function file(bytes32 what, bool flag) public;
    function balance() public;
}

contract SwitchableDistributorFab {
    function newDistributor(address currency) public returns (address) {
        SwitchableDistributor distributor = new SwitchableDistributor(currency);

        distributor.rely(msg.sender);
        distributor.deny(address(this));
        return address(distributor);
    }
}

contract DefaultDistributorFab {
    function newDistributor(address currency) public returns (address) {
        DefaultDistributor distributor = new DefaultDistributor(currency);
        distributor.rely(msg.sender);
        distributor.deny(address(this));
        return address(distributor);
    }
}
contract AssessorLike {
    function rely(address usr) public;
    function deny(address usr) public;
    function depend(bytes32 what, address addr_) public;
    function file(bytes32 what, uint value) public;
}

contract LenderDeployer is Auth {
    address rootAdmin;
    address deployUser;

    // Fabs
    TrancheFab trancheFab;
    SeniorTrancheFab seniorTrancheFab;
    AssessorFab assessorFab;
    DistributorFab distributorFab;

    OperatorFab juniorOperatorFab;
    OperatorFab seniorOperatorFab;

    address public currency;

    // Contracts
    AssessorLike public assessor;
    DistributorLike public distributor;

    // junior
    Tranche public junior;
    address public junior_;
    ERC20 public juniorERC20;
    OperatorLike public juniorOperator;

    // optional senior
    SeniorTranche public senior;
    address public senior_;
    ERC20 public seniorERC20;
    OperatorLike public seniorOperator;

    constructor(address rootAdmin_, address currency_, address trancheFab_, address assessorFab_,
        address juniorOperatorFab_, address distributorFab_) public {

        deployUser = msg.sender;
        rootAdmin = rootAdmin_;

        wards[deployUser] = 1;
        wards[rootAdmin] = 1;

        currency = currency_;

        trancheFab = TrancheFab(trancheFab_);
        assessorFab = AssessorFab(assessorFab_);
        juniorOperatorFab = OperatorFab(juniorOperatorFab_);

        distributorFab = DistributorFab(distributorFab_);
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "senior_tranche_fab") { seniorTrancheFab = SeniorTrancheFab(addr); }
        else if (what == "senior_operator_fab") { seniorOperatorFab = OperatorFab(addr); }
        else revert();
    }

    function deployDistributor() public auth {
        distributor = DistributorLike(distributorFab.newDistributor(currency));
        distributor.rely(rootAdmin);
    }

    function deploySeniorTranche(string memory symbol, string memory name) public auth {
        require(address(assessor) != address(0));
        seniorERC20 = new ERC20(symbol, name);
        senior = seniorTrancheFab.newSeniorTranche(currency, address(seniorERC20), address(assessor));
        senior_ = address(senior);
        // senior tranche can mint
        seniorERC20.rely(address(senior));
        senior.rely(rootAdmin);
    }

    function deployJuniorTranche(string memory symbol, string memory name) public auth {
        juniorERC20 = new ERC20(symbol, name);
        junior = trancheFab.newTranche(currency, address(juniorERC20));
        junior_ = address(junior);
        // tranche can mint
        juniorERC20.rely(address(junior));
        junior.rely(rootAdmin);
    }

    function deployAssessor() public auth {
        assessor = AssessorLike(assessorFab.newAssessor());
        assessor.rely(rootAdmin);
    }

    function deployJuniorOperator() public auth {
        require(address(assessor) != address(0));
        require(address(junior) != address(0));
        require(address(distributor) != address(0));

        juniorOperator = OperatorLike(juniorOperatorFab.newOperator(address(junior), address(assessor), address(distributor)));
        juniorOperator.rely(rootAdmin);
    }

    function deploySeniorOperator() public auth {
        require(address(assessor) != address(0));
        require(address(senior) != address(0));
        require(address(distributor) != address(0));

        seniorOperator = OperatorLike(seniorOperatorFab.newOperator(address(senior), address(assessor), address(distributor)));
        seniorOperator.rely(rootAdmin);
    }

    function deploy() public auth {
        // if juniorOperator is defined all required deploy methods were called
        require(address(juniorOperator) != address(0));

        junior.rely(address(juniorOperator));
        junior.rely(address(distributor));

        distributor.depend("junior", junior_);
        assessor.depend("junior", junior_);

        if (senior_ != address(0)) {
            senior.rely(address(seniorOperator));
            senior.rely(address(distributor));
            distributor.depend("senior" , senior_);
            assessor.depend("senior" , senior_);
        }

        // remove access of deployUser
        deny(deployUser);
    }
}