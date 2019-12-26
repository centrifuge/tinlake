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
import "ds-math/math.sol";

import { SystemTest, ERC20Like } from "../core/test/system/system.t.sol";
import { Deployer } from "../core/deployer.sol";
import { ProxyDeployer, AccessRegistryFab, RegistryFab, FactoryFab } from "../proxy/deployer.sol";
import { Title } from "../core/title.sol";
import { Actions } from "../actions/actions.sol";
import { Proxy } from "../proxy/proxy.sol";
import { User } from "./user.sol";
import "./functional.t.sol";
import {CollectDeployer} from "../core/collect/deployer.sol";


contract CollectTest is FunctionalTest,DSMath {

    CollectDeployer public collectDeployer;

    function setUp() public {
        basicSetup();
    }

    function collect(uint loan, uint tokenId, uint principal, uint appraisal, uint fee) public {
        bool seizable = collectDeployer.spotter().seizable(loan);
        assertTrue(seizable==true);

        assertTrue(collectDeployer.spotter().collectable(loan) == false);

        // seizure loan
        collectDeployer.spotter().seizure(loan);
        assertTrue(collectDeployer.spotter().collectable(loan));

        // allow test to collect NFT's
        systemTest.admin().doAddKeeper(address(this));

        assertTrue(systemTest.deployer().pile().Debt() != 0);

        setUpRepayLiquidity(address(this), 2000 ether);
        // collect NFT
        collectDeployer.collector().collect(loan, address(this));

        assertEq(ERC721Like(tinlake.collateralNFT_).ownerOf(tokenId), address(this));
        assertEq(systemTest.deployer().pile().Debt(), 0);
    }

    function setupLoan() public returns (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) {
        (uint tokenId, uint principal, uint appraisal, uint fee) = systemTest.defaultLoan();
        uint loan = whitelistAndBorrow(tokenId, principal, appraisal, fee);

        collectDeployer = CollectDeployer(address(systemTest.deployer().collectDeployer()));

        // intial threshold and ratio at 120%
        assertEq(collectDeployer.spotter().threshold(), rdiv(appraisal, principal));

        bool seizable = collectDeployer.spotter().seizable(loan);
        assertTrue(seizable==false);
        return (loan, tokenId, principal, appraisal, fee);

    }

    function testCollectDebtTooHigh() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) = setupLoan();
        systemTest.hevm().warp(now + 10 days);
        collect(loan, tokenId, principal, appraisal, fee);
    }

    function testCollectPriceTooLow() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) = setupLoan();

        // decrease appraisal
        systemTest.admin().doUpdateAppraisal(loan, appraisal/2);

        collect(loan, tokenId, principal, appraisal, fee);
    }

    function testFailRepayDefaultedLoan() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) = setupLoan();
        systemTest.hevm().warp(now + 10 days);
        collect(loan, tokenId, principal, appraisal, fee);

        close(loan, tokenId, principal);
    }
}

