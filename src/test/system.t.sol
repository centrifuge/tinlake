// Copyright (C) 2019 lucasvo

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

import "../deployer.sol";
import "../appraiser.sol";
import "./simple/nft.sol";
import "./simple/token.sol";
import "./simple/lender.sol";

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
}

contract BorrowerUser {
    TokenLike tkn;
    Reception reception;
    constructor (address reception_, address tkn_) public {
        reception = Reception(reception_);
        tkn = TokenLike(tkn_);
    }

    function doBorrow (uint loan) public {
     reception.borrow(loan, address(this));
    }
    function doApproveNFT(SimpleNFT nft, address usr) public {
        nft.setApprovalForAll(usr, true);
    }
    function doRepay(uint loan, uint wad, address usrT, address usrC) public {
        reception.repay(loan, wad, usrT, usrC);
    }

    function doApprove(address usr, uint wad) public {
        tkn.approve(usr, wad);
    }
}

contract ManagerUser {
    // --- Data ---
    Deployer    deployer;
    Appraiser appraiser;

    constructor (Appraiser appraiser_) public {
        appraiser = appraiser_;
    }

    function file (Deployer deployer_) public {
        deployer = deployer_;
    }

    function doAdmit(address registry, uint nft, uint principal, uint value, address usr) public returns (uint) {
        uint loan = deployer.admit().admit(registry, nft, principal, usr);
        appraiser.file(loan, value);
        return loan;
    }
}

contract SystemTest is DSTest {
    SimpleNFT    nft;
    address      nft_;
    SimpleToken  tkn;
    address      tkn_;
    address      lenderfab;
    Appraiser    appraiser;
    Deployer     deployer;

    ManagerUser  manager;
    address      manager_;
    BorrowerUser borrower;
    address      borrower_;

    function setUp() public {
        nft = new SimpleNFT();
        nft_ = address(nft);

        tkn = new SimpleToken("DTKN", "Dummy Token", "1", 0);
        tkn_ = address(tkn);

        lenderfab = address(new SimpleLenderFab());
        TitleFab titlefab = new TitleFab();
        LightSwitchFab lightswitchfab = new LightSwitchFab();
        PileFab pilefab = new PileFab();
        ShelfFab shelffab = new ShelfFab();
        CollateralFab collateralfab = new CollateralFab();
        appraiser = new Appraiser();

        manager = new ManagerUser(appraiser);
        manager_ = address(manager);
        appraiser.rely(manager_);

        deployer = new Deployer(manager_, titlefab, lightswitchfab, pilefab, shelffab, collateralfab);
        deployer.deployLightSwitch();
        deployer.deployTitle("Tinlake Loan", "TLNT");
        deployer.deployCollateral();
        deployer.deployPile(tkn_);
        deployer.deployShelf(address(appraiser));
        deployer.deployValve();
        deployer.deploy();
        deployer.deployLender(tkn_, lenderfab);

        borrower = new BorrowerUser(address(deployer.reception()),tkn_);
        borrower_ = address(borrower);

        manager.file(deployer);
    }

    // Checks
    function checkAfterBorrow(uint loan, uint tokenId, uint tBalance, uint cBalance) public {
        assertEq(tkn.balanceOf(borrower_), tBalance);
        assertEq(deployer.collateral().totalSupply(), cBalance);
        assertEq(deployer.collateral().balanceOf(address(deployer.lender())), cBalance);
        assertEq(nft.ownerOf(tokenId), address(deployer.shelf()));
    }

    function checkAfterRepay(uint loan, uint tokenId, uint tTotal, uint cTotal, uint tLender) public {
        assertEq(nft.ownerOf(tokenId), borrower_);
        assertEq(deployer.pile().debtOf(loan), 0);
        assertEq(tkn.balanceOf(borrower_), tTotal-tLender);
        assertEq(tkn.balanceOf(address(deployer.pile())), 0);
        assertEq(tkn.balanceOf(address(deployer.lender())), tLender);
        assertEq(deployer.collateral().balanceOf(address(deployer.desk())), 0);
        assertEq(deployer.collateral().totalSupply(), cTotal);
    }

    // Tests
    function testBorrowTransaction() public {
        uint tokenId = 1;
        // nft value
        uint principal = 100;
        uint appraisal = 120;

        // create borrower collateral nft
        nft.mint(borrower_, tokenId);
        uint loan = manager.doAdmit(nft_, tokenId, principal, appraisal, borrower_);
        borrower.doApproveNFT(nft, address(deployer.shelf()));
        borrower.doBorrow(loan);

        checkAfterBorrow(loan, tokenId, principal, appraisal);
    }

    function testBorrowAndRepay() public {
        uint tokenId = 1;

        // create borrower collateral nft
        nft.mint(borrower_, tokenId);

        // nft value
        uint principal = 100;
        uint appraisal = 120;

        // nft whitelist
        uint loan = manager.doAdmit(nft_, tokenId, principal, appraisal, borrower_);
        borrower.doApproveNFT(nft, address(deployer.shelf()));

        // borrow transaction
        borrower.doBorrow(loan);

        checkAfterBorrow(loan, tokenId, principal, appraisal);


        // allow pile full control over borrower tokens
        borrower.doApprove(address(deployer.pile()), uint(-1));

        // repay transaction
        borrower.doRepay(loan, principal, borrower_, borrower_);


        checkAfterRepay(loan, tokenId, principal, 0, principal);
    }

    function testMultipleBorrowAndRepay () public {
        uint principal = 100;
        uint appraisal = 120;

        uint cTotalSupply = 0;
        uint tTotalSupply = 0;

        // borrow
        for (uint i = 0; i < 10; i++) {
            appraisal = (i+1)*100;
            principal = appraisal/100 * 80;

            // create borrower collateral nft
            nft.mint(borrower_, i);

            // nft whitelist
            manager.doAdmit(nft_, i, principal, appraisal, borrower_);
            borrower.doApproveNFT(nft, address(deployer.shelf()));


            // borrow transaction
            borrower.doBorrow(i);

            cTotalSupply += appraisal;
            tTotalSupply += principal;
            checkAfterBorrow(i, i, tTotalSupply,cTotalSupply);
        }

        // repay

        // allow pile full control over borrower tokens
        borrower.doApprove(address(deployer.pile()), uint(-1));

        uint tLenderBalance = 0;

        for (uint i = 0; i < 10; i++) {
            appraisal = (i+1)*100;
            principal = appraisal/100 * 80;

            // repay transaction
            borrower.doRepay(i, principal, borrower_, borrower_);

            cTotalSupply -= appraisal;
            tLenderBalance += principal;

            checkAfterRepay(i,i,tTotalSupply, cTotalSupply, tLenderBalance);
        }
    }

    function testFailBorrowSameTokenIdTwice() public {
        uint tokenId = 1;
        // nft value
        uint principal = 100;
        uint appraisal = 120;

        // create borrower collateral nft
        nft.mint(borrower_, tokenId);
        uint loan = manager.doAdmit(nft_, tokenId, principal, appraisal, borrower_);
        borrower.doApproveNFT(nft, address(deployer.shelf()));
        borrower.doBorrow(loan);
        checkAfterBorrow(loan, tokenId, principal, appraisal);

        // should fail
        borrower.doBorrow(loan);
    }

    function testFailBorrowNonExistingToken() public {
        borrower.doBorrow(42);
        assertEq(tkn.balanceOf(borrower_), 0);
    }

    function testFailBorrowNotWhitelisted() public {
        uint nft_tokenId = 1;
        nft.mint(borrower_, nft_tokenId);
        borrower.doBorrow(1);
        assertEq(tkn.balanceOf(borrower_), 0);
    }

    function testFailAdmitNonExistingNFT() public {
        uint loan = manager.doAdmit(nft_, 1, 100, 120, borrower_);
        borrower.doBorrow(loan);
        assertEq(tkn.balanceOf(borrower_), 0);
    }

    function testFailBorrowNFTNotApproved() public {
        uint nft_tokenId = 1;
        nft.mint(borrower_, nft_tokenId);
        uint loan = manager.doAdmit(nft_, nft_tokenId, 100, 120, borrower_);
        borrower.doBorrow(loan);
        assertEq(tkn.balanceOf(borrower_), 100);
    }
}


