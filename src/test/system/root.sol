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

import { TinlakeRoot } from "../../root.sol";

contract AuthLike {
    function rely(address) public;
    function deny(address) public;
}

contract TestRoot is TinlakeRoot {
    // Permissions
    // To simplify testing, we add helpers to authorize contracts on any component.

    // Needed for System Tests
    function relyBorrowAdmin(address usr) public auth {
        AuthLike(borrowerDeployer.title()).rely(usr);
        AuthLike(borrowerDeployer.shelf()).rely(usr);
        AuthLike(borrowerDeployer.pile()).rely(usr);
        AuthLike(borrowerDeployer.ceiling()).rely(usr);
        AuthLike(borrowerDeployer.collector()).rely(usr);
        AuthLike(borrowerDeployer.threshold()).rely(usr);
    }

    // Needed for System Tests
    function relyLenderAdmin(address usr, bool senior_) public auth {
        AuthLike(lenderDeployer.juniorOperator()).rely(usr);
        AuthLike(lenderDeployer.assessor()).rely(usr);
        AuthLike(lenderDeployer.distributor()).rely(usr);
        AuthLike(lenderDeployer.junior()).rely(usr);

        if (senior_) {
            AuthLike(lenderDeployer.seniorOperator()).rely(usr);
            AuthLike(lenderDeployer.senior()).rely(usr);
        }
    }

    function denyLenderAdmin(address usr, bool senior_) public auth {
        AuthLike(lenderDeployer.juniorOperator()).deny(usr);
        AuthLike(lenderDeployer.assessor()).deny(usr);
        AuthLike(lenderDeployer.distributor()).deny(usr);
        AuthLike(lenderDeployer.junior()).deny(usr);

        if (senior_) {
            AuthLike(lenderDeployer.seniorOperator()).deny(usr);
            AuthLike(lenderDeployer.senior()).deny(usr);
        }
    }

    function denyBorrowAdmin(address usr) public auth {
        AuthLike(borrowerDeployer.title()).deny(usr);
        AuthLike(borrowerDeployer.ceiling()).deny(usr);
        AuthLike(borrowerDeployer.shelf()).deny(usr);
        AuthLike(borrowerDeployer.pile()).deny(usr);
    }
}
