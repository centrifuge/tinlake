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

import {
  TitleFab,
  ShelfFab,
  PileFab,
  NFTFeedFab,
  NAVFeedFab,
  CollectorFab,
  BorrowerDeployer
} from "../../borrower/deployer.sol";

import { Title } from "tinlake-title/title.sol";
import { Pile } from "../../borrower/pile.sol";
import { Shelf } from "../../borrower/shelf.sol";
import { Collector } from "../../borrower/collect/collector.sol";

import "../../lender/deployer.sol";

import { TestRoot } from "./root.sol";

import "../simple/token.sol";
import "../simple/distributor.sol";

import "tinlake-erc20/erc20.sol";
import { PushRegistry } from "tinlake-registry/registry.sol";
import { TokenLike, NFTFeedLike } from "./interfaces.sol";

contract DistributorLike {
    function balance() public;
}

contract TestSetup {
    Title public collateralNFT;
    address      public collateralNFT_;
    SimpleToken  public currency;
    address      public currency_;

    // Borrower contracts
    Shelf        shelf;
    Pile         pile;
    Title        title;
    NFTFeedLike  nftFeed;
    Collector    collector;


    // Lender contracts
    DistributorLike  distributor;


    // Deployers
    BorrowerDeployer public borrowerDeployer;
    MockLenderDeployer public   lenderDeployer;

    TestRoot root;
    address  root_;

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function deployContracts(bytes32 feed_) public {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);

        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);

        root = new TestRoot(address(this));
        root_ = address(root);

        // only admin is main deployer
        deployBorrower(feed_);
        // only admin is main deployer

        deployMockLender();

        root.prepare(address(lenderDeployer), address(borrowerDeployer), address(this));
        root.deploy();
    }

    function deployBorrower(bytes32 feed_) private {
        TitleFab titlefab = new TitleFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        CollectorFab collectorFab = new CollectorFab();
        address nftFeedFab_;

        if (feed_ == "default") {
            nftFeedFab_ = address(new NFTFeedFab());
        } else if (feed_ == "nav") {
            nftFeedFab_ = address(new NAVFeedFab());
        }

        borrowerDeployer = new BorrowerDeployer(root_, titlefab, shelffab, pileFab, collectorFab, nftFeedFab_, currency_, "Tinlake Loan Token", "TLNT");

        borrowerDeployer.deployTitle();
        borrowerDeployer.deployPile();
        borrowerDeployer.deployFeed();
        borrowerDeployer.deployShelf();
        borrowerDeployer.deployCollector();
        borrowerDeployer.deploy();

        shelf = Shelf(borrowerDeployer.shelf());
        pile = Pile(borrowerDeployer.pile());
        title = Title(borrowerDeployer.title());
        collector = Collector(borrowerDeployer.collector());
        nftFeed = NFTFeedLike(borrowerDeployer.feed());
    }

    function deployMockLender() public {
        lenderDeployer = new MockLenderDeployer(root_, currency_);
        distributor = DistributorLike(lenderDeployer.distributor_());

    }

}
