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
        // proxy owns collateral NFT
        (uint tokenId, uint principal, uint appraisal, uint fee) = systemTest.defaultLoan();
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
    }

    function testBorrowRepay() public {
        // setup initial loan + borrow
        (uint tokenId, uint principal, uint appraisal, uint fee) = systemTest.defaultLoan();
        mintCollateralNFT(proxy_, tokenId);
        uint loan = systemTest.whitelist(tokenId, tinlake.collateralNFT_, principal, appraisal, proxy_, fee);
        borrower.approve(proxy_,  actions_, tinlake.collateralNFT_, tinlake.shelf_, tokenId);
        borrower.borrow(proxy_, actions_, tinlake.desk_, tinlake.pile_, tinlake.shelf_, loan, proxy_);

        systemTest.hevm().warp(now + 10 days);

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
}
