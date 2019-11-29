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
import { Executor } from "./executor.sol";

contract FunctionalTest is DSTest {

    Deployer coreDeployer;
    ProxyDeployer proxyDeployer;
    SystemTest systemTest;
    Executor  executor;

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
        Title accessRegistry = accessRegistryFab.newAccessRegistry("Tinlake", "TLT");

        FactoryFab factoryfab = new FactoryFab();
        RegistryFab registryfab = new RegistryFab();

        proxyDeployer = new ProxyDeployer(address(this), factoryfab, registryfab);
        accessRegistry.rely(address(proxyDeployer));
        registry_ = proxyDeployer.deployProxyStation(address(accessRegistry));
    }

    function buildProxy() public returns (address payable) {
       return proxyDeployer.deployProxy(registry_, address(this));
    }

    function setUpActions() public {
        actions_ = address(new Actions());
        executor = new Executor();
    }

    function fetchTinlakeAddr() public {
        tinlake = Tinlake(
            systemTest.nft_(),
            address(coreDeployer.shelf()),
            address(coreDeployer.pile()),
            address(coreDeployer.desk()),
            address(coreDeployer.title()),
            address(systemTest.tkn())
        );
    }

    function setUp() public {
        systemTest = new SystemTest();
        systemTest.setUp();
        coreDeployer = systemTest.deployer();

        setUpProxyStation();
        proxy_ = buildProxy();
        setUpActions();

        fetchTinlakeAddr();
    }

    function mintCollateralNFT(address proxy_, uint tokenId) public {
        // create borrower collateral nft
        systemTest.nft().mint(proxy_, tokenId);
    }

    function testSimpleBorrow () public {
        // proxy owns collateral NFT
        (uint tokenId, uint principal, uint appraisal, uint fee) = systemTest.defaultLoan();
        mintCollateralNFT(proxy_, tokenId);
        //check collateral NFT owner
        assertEq(Title(tinlake.collateralNFT_).ownerOf(tokenId), proxy_);
        // whitelist
        uint loan = systemTest.whitelist(tokenId, tinlake.collateralNFT_, principal, appraisal, proxy_, fee);
        // check loan NFT owner
        assertEq(Title(tinlake.title_).ownerOf(loan), proxy_);
        emit log_named_address('nft', tinlake.collateralNFT_);

//        executor.approve(proxy_,  actions_, tinlake.collateralNFT_, tinlake.shelf_, tokenId);
        approve(proxy_,  actions_, tinlake.collateralNFT_, tinlake.shelf_, tokenId);
        assertEq(Title(tinlake.collateralNFT_).getApproved(tokenId), tinlake.shelf_);

//        executor.borrow(proxy_, actions_, tinlake.desk_, tinlake.pile_, tinlake.shelf_, loan, proxy_);
        borrow(proxy_, actions_, tinlake.desk_, tinlake.pile_, tinlake.shelf_, loan, proxy_);
        assertEq(Title(tinlake.collateralNFT_).ownerOf(tokenId), tinlake.shelf_);
        assertEq(ERC20Like(tinlake.currency_).balanceOf(proxy_), principal);
    }

    function approve(address payable proxy_, address actions_, address nft_, address approvee_, uint tokenId) public returns (bytes memory) {
        bytes memory data = abi.encodeWithSignature("approve(address,address,uint256)", nft_, approvee_, tokenId);
        return Proxy(proxy_).execute(actions_, data);
    }

    function borrow(address payable proxy_, address actions_, address desk_, address pile_, address shelf_, uint loan, address deposit) public returns (bytes memory) {
        bytes memory data = abi.encodeWithSignature("borrow(address,address,address,uint256,address)", desk_, pile_, shelf_, loan, deposit);
        return Proxy(proxy_).execute(actions_, data);
    }
}

