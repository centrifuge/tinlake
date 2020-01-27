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
    BorrowerDeployer borrowerDeployer;
    LenderDeployer lenderDeployer;

    constructor () public {
        wards[msg.sender] = 1;
    }

    function file(bytes32 what, address deployer) public auth {
        if(what == "borrower") borrowerDeployer = BorrowerDeployer(deployer);
        else if (what == "lender") lenderDeployer = LenderDeployer(deployer);
        else revert();
    }


    function deploy() public auth {
        require(address(borrowerDeployer) != address(0));
        require(address(lenderDeployer) != address(0));

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
