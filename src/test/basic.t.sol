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

pragma solidity >=0.4.23;

import "ds-test/test.sol";

import { SystemTest, ERC20Like } from "../core/test/system/system.t.sol";
import { Deployer } from "../core/deployer.sol";
import { ProxyDeployer, AccessRegistryFab, RegistryFab, FactoryFab } from "../proxy/deployer.sol";
import { Title } from "../core/title.sol";
import { Actions } from "../actions/actions.sol";
import { Proxy } from "../proxy/proxy.sol";
import { User } from "./user.sol";
import "./functional.t.sol";

contract BasicTest is FunctionalTest {

    function setUp() public {
        basicSetup();
    }

    function testSimpleBorrow() public {
        (uint tokenId, uint principal, uint appraisal, uint fee) = systemTest.defaultLoan();
        whitelistAndBorrow(tokenId, principal, appraisal, fee);
    }

    function testBorrowClose() public {
        (uint tokenId, uint principal, uint appraisal, uint fee) = systemTest.defaultLoan();
        uint loan = whitelistAndBorrow(tokenId, principal, appraisal, fee);

        systemTest.hevm().warp(now + 10 days);
        close(loan, tokenId, principal);
    }
}
