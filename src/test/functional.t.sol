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

contract PileLike {
    function balanceOf(uint loan) public returns (uint);
    function debtOf(uint loan) public returns (uint);
    function collect(uint loan) public;
}

contract FunctionalTest is DSTest {

    Deployer coreDeployer;
    ProxyDeployer proxyDeployer;
    SystemTest systemTest;
    User borrower;

    // proxy addresses
    address registry_;
    address payable proxy_;
    address actions_;

    struct Tinlake {
        address collateralNFT_;
        address shelf_;
        address pile_;
        address desk_;
        address title_;
        address currency_;
    }

    Tinlake tinlake;

    function setUpProxyStation() public {
        AccessRegistryFab accessRegistryFab = new AccessRegistryFab();
        Title accessRegistry = accessRegistryFab.newAccessNFTRegistry("Tinlake", "TLT");

        FactoryFab factoryfab = new FactoryFab();
        RegistryFab registryfab = new RegistryFab();

        proxyDeployer = new ProxyDeployer(address(this), factoryfab, registryfab);
        accessRegistry.rely(address(proxyDeployer));
        registry_ = proxyDeployer.deployProxyRegistry(address(accessRegistry));
    }

    function buildProxy() public returns (address payable) {
       return proxyDeployer.deployProxy(registry_, address(borrower));
    }

    function setUpActions() public {
        actions_ = address(new Actions());
        borrower = new User();
    }

    function fetchTinlakeAddr() public {
        tinlake = Tinlake(
            systemTest.nft_(),
            address(coreDeployer.shelf()),
            address(coreDeployer.pile()),
            address(coreDeployer.desk()),
            address(coreDeployer.title()),
            systemTest.tkn_()
        );
    }

    function basicSetup() public {
        systemTest = new SystemTest();
        systemTest.setUp();
        coreDeployer = systemTest.deployer();
        setUpActions();

        setUpProxyStation();
        proxy_ = buildProxy();

        fetchTinlakeAddr();
    }

    function mintCollateralNFT(address proxy_, uint tokenId) public {
        // create borrower collateral nft
        systemTest.nft().mint(proxy_, tokenId);
    }

    function setUpRepayLiquidity(address proxy_, uint liquidity) public  {
        ERC20Like(tinlake.currency_).mint(proxy_, liquidity);
        // allow pile to spend borrower tokens
        ERC20Like(tinlake.currency_).approve(tinlake.pile_, uint(-1));
    }

}
