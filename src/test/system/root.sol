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

import "../../root_admin.sol";

contract TestRootAdmin is RootAdmin {
    // Permissions

    // Needed for System Tests
    function relyBorrowAdmin(address usr) public auth {
        borrowerDeployer.title().rely(usr);
        borrowerDeployer.shelf().rely(usr);
        borrowerDeployer.pile().rely(usr);
        borrowerDeployer.principal().rely(usr);
        borrowerDeployer.collector().rely(usr);
        borrowerDeployer.threshold().rely(usr);
    }

    // Needed for System Tests
    function relyLenderAdmin(address usr, bool senior_) public auth {
        lenderDeployer.juniorOperator().rely(usr);
        lenderDeployer.assessor().rely(usr);
        lenderDeployer.distributor().rely(usr);
        lenderDeployer.junior().rely(usr);

        if (senior_) {
            lenderDeployer.seniorOperator().rely(usr);
            lenderDeployer.senior().rely(usr);
        }
    }

    function denyLenderAdmin(address usr, bool senior_) public auth {
        lenderDeployer.juniorOperator().deny(usr);
        lenderDeployer.assessor().deny(usr);
        lenderDeployer.distributor().deny(usr);
        lenderDeployer.junior().deny(usr);

        if (senior_) {
            lenderDeployer.seniorOperator().deny(usr);
            lenderDeployer.senior().deny(usr);
        }
    }

    function denyBorrowAdmin(address usr) public auth {
        borrowerDeployer.title().deny(usr);
        borrowerDeployer.principal().deny(usr);
        borrowerDeployer.shelf().deny(usr);
        borrowerDeployer.pile().deny(usr);
    }
}