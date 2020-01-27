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
pragma solidity >=0.5.3;

import { BorrowerDeployer } from "./borrower/deployer.sol";
import { LenderDeployer } from "./lender/deployer.sol";

import "tinlake-auth/auth.sol";

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
}

contract DependLike {
    function depend(bytes32, address) public;
}


contract TinlakeRoot is Auth {
    BorrowerDeployer public borrowerDeployer;
    LenderDeployer public   lenderDeployer;

    bool public             deployed;
    address public          deployUsr;

    constructor (address deployUsr_) public {
        deployUsr = deployUsr_;
    }

    // --- Prepare ---
    // Sets the two deployer dependencies. This needs to be called by the deployUsr;
    function prepare(address lender_, address borrower_, address ward_) public {
        require(deployUsr == msg.sender);
        borrowerDeployer = BorrowerDeployer(borrower_);
        lenderDeployer = LenderDeployer(lender_);
        wards[ward_] = 1;
        deployUsr = address(0); // disallow the deploy user to call this more than once.
    }


    // --- Governance Functions ---
    // `relyContract` & `denyContract` can be called by any ward on the TinlakeRoot
    // contract to make an arbitrary address a ward on any contract the TinlakeRoot
    // is a ward on.
    function relyContract(address target, address usr) public auth {
        AuthLike(target).rely(usr);
    }

    function denyContract(address target, address usr) public auth {
        AuthLike(target).deny(usr);
    }


    // --- Deploy ---
    function deploy() public {
        require(address(borrowerDeployer) != address(0) && address(lenderDeployer) != address(0) && deployed == false);

        address distributor_ = lenderDeployer.distributor();
        address shelf_ = borrowerDeployer.shelf();

        // Borrower depends
        DependLike(borrowerDeployer.collector()).depend("distributor", distributor_);
        DependLike(borrowerDeployer.shelf()).depend("lender", distributor_);
        DependLike(borrowerDeployer.collector()).depend("distributor", distributor_);
        DependLike(borrowerDeployer.shelf()).depend("distributor", distributor_);

        //  Lender depends
        address poolValue = borrowerDeployer.pricePool();
        DependLike(lenderDeployer.distributor()).depend("shelf", shelf_);
        DependLike(lenderDeployer.assessor()).depend("pool", poolValue);
    }

}
