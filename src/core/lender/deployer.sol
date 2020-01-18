// Copyright (C) 2019 Centrifuge
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
import "tinlake-auth/auth.sol";

import { Distributor } from "../test/simple/distributor.sol";

contract DistributorFab {
    // note: this is the mock distributor, which will interface with the lender/tranche side of Tinlake, and does not require auth for now.
    function newDistributor(address token_) public returns (Distributor distributor) {
        distributor = new Distributor(token_);
        distributor.rely(msg.sender);
        distributor.deny(address(this));
        return distributor;
    }
}

// todo replace with real deployer, currently only a mockDistributor is deployed
contract LenderDeployer {
    DistributorFab    distributorFab;
    Distributor  public distributor;
    address mainDeployer;

    constructor(address mainDeployer_, DistributorFab distributorFab_) public {
        mainDeployer = mainDeployer_;
        distributorFab = distributorFab_;
    }

    function deployDistributor(address currency_) public {
        distributor = distributorFab.newDistributor(currency_);

    }

    function deploy() public {
        distributor.rely(mainDeployer);
    }
}
