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

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import { Title } from "tinlake-title/title.sol";
import "../../borrower/deployer.sol";
import "../../lender/deployer.sol";
import "./root_admin.sol";

import "../simple/token.sol";

import "tinlake-erc20/erc20.sol";



contract ERC20Like {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
    function totalSupply() public returns (uint256);
    function balanceOf(address usr) public returns (uint);
}

contract Hevm {
    function warp(uint256) public;
}

contract ShelfLike {
    function shelf(uint loan) public returns(address registry,uint256 tokenId,uint price,uint principal, uint initial);
}

contract CeilingLike {
    function values(uint) public view returns(uint);
}

contract User is DSTest{
    ERC20Like tkn;
    Shelf shelf;
    DistributorLike distributor;
    Pile pile;

    constructor (address shelf_, address distributor_, address tkn_, address pile_) public {
        shelf = Shelf(shelf_);
        distributor = DistributorLike(distributor_);
        tkn = ERC20Like(tkn_);
        pile = Pile(pile_);
    }

    function doBorrow(uint loan, uint amount) public {
        shelf.lock(loan, address(this));
        shelf.borrow(loan, amount);
        distributor.balance();
        shelf.withdraw(loan, amount, address(this));
    }

    function doApproveNFT(Title nft, address usr) public {
        nft.setApprovalForAll(usr, true);
    }

    function doRepay(uint loan, uint wad, address usr) public {
        emit log_named_uint("loan", wad);
        shelf.repay(loan, wad);
        emit log_named_uint("loan", wad);
        shelf.unlock(loan);
        emit log_named_uint("loan", wad);
        distributor.balance();
    }

    function doClose(uint loan, address usr) public {
        uint debt = pile.debt(loan);
        doRepay(loan, debt, usr);
    }

    function doApproveCurrency(address usr, uint wad) public {
        tkn.approve(usr, wad);
    }
}

contract AdminUser is DSTest{
    // --- Data ---
    BorrowerDeployer  deployer;

    function file (BorrowerDeployer deployer_) public {
        deployer = deployer_;
    }

    function doAdmit(address registry, uint nft, uint principal, address usr) public returns (uint) {
        uint loan = deployer.title().issue(usr);
        deployer.principal().file(loan, principal);
        deployer.shelf().file(loan, registry, nft);
        return loan;
    }

    function doInitRate(uint rate, uint speed) public {
        deployer.pile().file(rate, speed);
    }

    function doAddRate(uint loan, uint rate) public {
        deployer.pile().setRate(loan, rate);
    }

    function addKeeper(address usr) public {
        // CollectDeployer cd = CollectDeployer(address(deployer.collectDeployer()));
        // cd.collector().rely(usr);
    }

    function doAddKeeper(address usr) public {
        // CollectDeployer cd = CollectDeployer(address(deployer.collectDeployer()));
        // cd.collector().rely(usr);
    }
}

contract TestUtils  {
    Title public collateralNFT;
    address      public collateralNFT_;
    SimpleToken  public currency;
    address      public currency_;

    // Deployers
    BorrowerDeployer public borrowerDeployer;
    LenderDeployer public lenderDeployer;


    TestRootAdmin rootAdmin;
    address rootAdmin_;

    function deployContracts() public {
        baseSetup();
        // only admin is main deployer
        deployBorrower();
        // only admin is main deployer
        deployDefaultLender();

        rootAdmin.file("borrower", address(borrowerDeployer));
        rootAdmin.file("lender", address(lenderDeployer));

        rootAdmin.completeDeployment();
    }

    function baseSetup() private {
        collateralNFT = new Title("Collateral NFT", "collateralNFT");
        collateralNFT_ = address(collateralNFT);

        currency = new SimpleToken("C", "Currency", "1", 0);
        currency_ = address(currency);

        rootAdmin = new TestRootAdmin();
        rootAdmin_ = address(rootAdmin);
    }

    function deployBorrower() private {
        TitleFab titlefab = new TitleFab();
        LightSwitchFab lightswitchfab = new LightSwitchFab();
        ShelfFab shelffab = new ShelfFab();
        PileFab pileFab = new PileFab();
        PrincipalFab principalFab = new PrincipalFab();
        CollectorFab collectorFab = new CollectorFab();
        ThresholdFab thresholdFab = new ThresholdFab();
        PricePoolFab pricePoolFab = new PricePoolFab();

        borrowerDeployer = new BorrowerDeployer(rootAdmin_, titlefab, lightswitchfab, shelffab, pileFab, principalFab, collectorFab, thresholdFab, pricePoolFab);

        borrowerDeployer.deployLightSwitch();
        borrowerDeployer.deployTitle("Tinlake Loan", "TLNT");
        borrowerDeployer.deployPile();
        borrowerDeployer.deployPrincipal();
        borrowerDeployer.deployShelf(currency_);

        borrowerDeployer.deployThreshold();
        borrowerDeployer.deployCollector();
        borrowerDeployer.deployPricePool();

        borrowerDeployer.deploy();

    }

    function deployDefaultLender() private {
        lenderDeployer = new LenderDeployer(rootAdmin_,address(new TrancheFab()), address(new AssessorFab()),
            address(new WhitelistFab()), address(new SwitchableDistributorFab()));

        lenderDeployer.deployJuniorTranche(currency_, "JUN", "Junior Tranche Token");

        lenderDeployer.deployAssessor();

        lenderDeployer.deployDistributor(currency_);

        lenderDeployer.deployJuniorOperator();

        lenderDeployer.deploy();

    }
}
