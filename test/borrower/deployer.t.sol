// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import { Title } from "tinlake-title/title.sol";
import { TitleFab } from "src/borrower/fabs/title.sol";
import { PileFab } from "src/borrower/fabs/pile.sol";
import { ShelfFab} from "src/borrower/fabs/shelf.sol";
import { TestNAVFeedFab } from "src/borrower/fabs/navfeed.tests.sol";

import "src/borrower/deployer.sol";
import { SimpleToken } from "../../test/simple/token.sol";

contract DeployerTest is Test {
    Title nft;
    SimpleToken dai;
    TitleFab titlefab;
    ShelfFab shelffab;
    PileFab pilefab;
    TestNAVFeedFab feedFab;
    Title title;

    function setUp() public {
        nft = new Title("SimpleNFT", "NFT");
        dai = new SimpleToken("DDAI", "Dummy Dai");
        titlefab = new TitleFab();
        shelffab = new ShelfFab();
        pilefab = new PileFab();
        feedFab = new TestNAVFeedFab();
   }

    function testBorrowerDeploy() public logs_gas {
        uint discountRate = uint(1000000342100000000000000000);
        BorrowerDeployer deployer = new BorrowerDeployer(address(0), address(titlefab), address(shelffab), address(pilefab), address(feedFab), address(dai), "Test", "TEST", discountRate);

        deployer.deployTitle();
        deployer.deployPile();
        deployer.deployFeed();
        deployer.deployShelf();
        deployer.deploy();
    }
}
