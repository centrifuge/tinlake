// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { TinlakeRoot } from "../../root.sol";
import { BorrowerDeployer } from "../../borrower/deployer.sol";
import { LenderDeployer } from "../../lender/deployer.sol";

import "ds-test/test.sol";
contract TestRoot is TinlakeRoot {
    constructor (address deployUsr, address governance) public TinlakeRoot(deployUsr, governance) {
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
