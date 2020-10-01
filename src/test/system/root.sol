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
pragma solidity >=0.5.15 <0.6.0;

import { TinlakeRoot } from "../../root.sol";
import { BorrowerDeployer } from "../../borrower/deployer.sol";
import { LenderDeployer } from "../../lender/deployer.sol";

import "ds-test/test.sol";
contract TestRoot is TinlakeRoot {
    constructor (address deployUsr) public TinlakeRoot(deployUsr) {
    }
    // Permissions
    // To simplify testing, we add helpers to authorize contracts on any component.

    // Needed for System Tests
    function relyBorrowerAdmin(address usr) public auth {
        BorrowerDeployer bD = BorrowerDeployer(address(borrowerDeployer));
        relyContract(bD.title(), usr);
        relyContract(bD.shelf(), usr);
        relyContract(bD.pile(), usr);
        relyContract(bD.feed(), usr);
        relyContract(bD.collector(), usr);
    }

    // Needed for System Tests
    function relyLenderAdmin(address usr) public auth {
        LenderDeployer lD = LenderDeployer(address(lenderDeployer));
        relyContract(lD.juniorMemberlist(), usr);
        relyContract(lD.seniorMemberlist(), usr);
    }

    function denyBorrowerAdmin(address usr) public auth {
        BorrowerDeployer bD = BorrowerDeployer(address(borrowerDeployer));
        denyContract(bD.title(), usr);
        denyContract(bD.feed(), usr);
        denyContract(bD.shelf(), usr);
        denyContract(bD.pile(), usr);
        denyContract(bD.collector(), usr);
    }
}
