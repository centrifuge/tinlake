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
import {PricePool} from "../price/pool.sol";

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
    function newAssessor(address pool) public returns (Assessor assessor) {
        assessor = new Assessor(pool);
        assessor.rely(msg.sender);
        assessor.deny(address(this));
    }
}

contract AllowanceFab {
    function newOperator(address tranche, address assessor) public returns (AllowanceOperator operator) {
        operator = new AllowanceOperator(tranche, assessor);
        operator.rely(msg.sender);
        operator.deny(address(this));
    }
}

contract WhitelistFab {
    function newOperator(address tranche, address assessor) public returns (WhitelistOperator operator) {
        operator = new WhitelistOperator(tranche, assessor);
        operator.rely(msg.sender);
        operator.deny(address(this));
    }
}

contract DistributorFab {
    function newDistributor() public returns (Distributor distributor) {
        distributor = new Distributor();
        distributor.rely(msg.sender);
        distributor.deny(address(this));
    }
}

// pool should be separate from lender deployer, this is just for now
contract PoolFab {
    function newPool() public returns (PricePool pool) {
        pool = new PricePool();
        pool.rely(msg.sender);
        pool.deny(address(this));
    }
}

contract PileLike {
    function total() public returns (uint);
}


contract CurrencyLike {
    function balanceOf(address) public returns(uint);
}

contract LenderDeployer {
    TrancheFab tranchefab;
    SeniorFab seniorfab;
    AssessorFab assessorfab;
    AllowanceFab allowancefab;
    WhitelistFab whitelistfab;
    DistributorFab distributorfab;
    // see pool comment above
    PoolFab poolfab;

    address god;

    Tranche public tranche;
    SeniorTranche public senior;
    Assessor public assessor;
    AllowanceOperator public allowance;
    WhitelistOperator public whitelist;
    Distributor public distributor;
    // see pool comment above
    PricePool public pool;


    constructor(address god_, TrancheFab trancheFab_, SeniorFab seniorFab_, AssessorFab assessorFab_, AllowanceFab allowanceFab_,
    WhitelistFab whitelistFab_, DistributorFab distributorFab_, PoolFab poolFab_) public {
        god = god_;
        tranchefab = trancheFab_;
        seniorfab = seniorFab_;
        assessorfab = assessorFab_;
        allowancefab = allowanceFab_;
        whitelistfab = whitelistFab_;
        distributorfab = distributorFab_;
        poolfab = poolFab_;
    }

    function deployTranche(address currency, address token) public {
        tranche = tranchefab.newTranche(currency, token);
        tranche.rely(god);
    }

    function deployPool() public {
        pool = poolfab.newPool();
        // pile needs to be added here;
        pool.rely(god);
    }

    function deployAssessor(address pool) public {
        assessor = assessorfab.newAssessor(pool);
        assessor.rely(god);
    }

    function deployWhitelistOperator(address tranche, address assessor) public {
        whitelist = whitelistfab.newOperator(tranche, assessor);
        whitelist.rely(god);
    }

    function deployAllowanceOperator(address tranche, address assessor) public {
        allowance = allowancefab.newOperator(tranche, assessor);
        allowance.rely(god);
    }

    function deployDistributor(address currency) public {
        distributor = distributorfab.newDistributor(currency);
        distributor.rely(god);
    }

    function elect(){}

    function impeach(){}
}
