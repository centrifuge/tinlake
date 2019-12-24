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

contract ERC721Like {
    function ownerOf(uint tokenId) public returns(address);
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

    function close(uint loan, uint tokenId, uint principal) public {
        uint extra = 100000000000 ether;
        // add liquidity for repayment
        setUpRepayLiquidity(proxy_, extra);
        assertEq(ERC20Like(tinlake.currency_).balanceOf(proxy_), extra + principal);
        assertEq(Title(tinlake.title_).ownerOf(loan), proxy_);

        // approve token transfer and close/repay loan
        borrower.approveERC20(proxy_, actions_, tinlake.currency_, tinlake.pile_, uint(-1));
        PileLike(tinlake.pile_).collect(loan);
        uint debt = PileLike(tinlake.pile_).debtOf(loan);
        borrower.close(proxy_, actions_, tinlake.desk_, tinlake.pile_, tinlake.shelf_, loan, proxy_);

        assertEq(ERC20Like(tinlake.currency_).balanceOf(proxy_), extra + principal -  debt);
        assertEq(PileLike(tinlake.pile_).balanceOf(loan), 0);
        assertEq(Title(tinlake.collateralNFT_).ownerOf(tokenId), proxy_);

    }

    function whitelistAndBorrow(uint tokenId, uint principal, uint appraisal, uint fee) public returns (uint) {
        // proxy owns collateral NFT
        mintCollateralNFT(proxy_, tokenId);
        assertEq(Title(tinlake.collateralNFT_).ownerOf(tokenId), proxy_);
        // whitelist
        uint loan = systemTest.whitelist(tokenId, tinlake.collateralNFT_, principal, appraisal, proxy_, fee);
        assertEq(Title(tinlake.title_).ownerOf(loan), proxy_);
        // approve collateral NFT transfer
        borrower.approve(proxy_,  actions_, tinlake.collateralNFT_, tinlake.shelf_, tokenId);
        assertEq(Title(tinlake.collateralNFT_).getApproved(tokenId), tinlake.shelf_);
        // borrow action
        borrower.borrow(proxy_, actions_, tinlake.desk_, tinlake.pile_, tinlake.shelf_, loan, proxy_);
        assertEq(Title(tinlake.collateralNFT_).ownerOf(tokenId), tinlake.shelf_);
        assertEq(ERC20Like(tinlake.currency_).balanceOf(proxy_), principal);
        return loan;
    }

}
