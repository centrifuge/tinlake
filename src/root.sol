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
import "./borrower/deployer.sol";
import "./lender/deployer.sol";

import "tinlake-auth/auth.sol";

contract RootAdmin is Auth {
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

    function dependContracts() internal  {
        address distributor_ = address(lenderDeployer.distributor());
        address shelf_ = address(borrowerDeployer.shelf());

        // Borrower  Depends
        borrowerDeployer.collector().depend("distributor", distributor_);

        // todo currently only one address approval in shelf
        borrowerDeployer.shelf().depend("lender", distributor_);
        borrowerDeployer.collector().depend("distributor", distributor_);
        borrowerDeployer.shelf().depend("distributor", distributor_);

        //  Lender depends
        address borrowerPricePool = address(borrowerDeployer.pricePool());
        lenderDeployer.distributor().depend("shelf", shelf_);
        lenderDeployer.assessor().depend("pool", borrowerPricePool);
    }

    function relyModules() internal {
        // distributor allowed to call
        borrowerDeployer.shelf().rely(address(lenderDeployer.distributor()));
    }

    function completeDeployment() public auth {
        require(address(borrowerDeployer) != address(0));
        require(address(lenderDeployer) != address(0));

        dependContracts();
        relyModules();
    }

}
