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

import "../../deployer.sol";
import "../../appraiser.sol";
import "../simple/nft.sol";
import "../simple/token.sol";
import "../simple/lender.sol";

contract ERC20Like {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
    function totalSupply() public returns (uint256);
}

contract User {
    ERC20Like tkn;
    ERC20Like collateral;
    Reception reception;
    constructor (address reception_, address tkn_, address collateral_) public {
        reception = Reception(reception_);
        tkn = ERC20Like(tkn_);
        collateral = ERC20Like(collateral_);
    }

    function doBorrow (uint loan) public {
        reception.borrow(loan, address(this));
    }
    function doApproveNFT(SimpleNFT nft, address usr) public {
        nft.setApprovalForAll(usr, true);
    }
    function doRepay(uint loan, uint wad, address usr) public {
        reception.repay(loan, wad, usr);
    }

    function doClose(uint loan, address usr) public {
        reception.close(loan, usr);
    }

    function doApproveCurrency(address usr, uint wad) public {
        tkn.approve(usr, wad);
    }
    function doApproveCollateral(address usr, uint wad) public {
        collateral.approve(usr, wad);
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

    function doInitFee(uint fee, uint speed) public {
        deployer.pile().file(fee, speed);
    }
    function doAddFee(uint loan, uint fee, uint balance) public {
        deployer.pile().file(loan, fee, balance);
    }
}

contract Hevm {
    function warp(uint256) public;
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
    User borrower;
    address      borrower_;
    Hevm hevm;



    function basicSetup() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        nft = new SimpleNFT();
        nft_ = address(nft);

        tkn = new SimpleToken("DTKN", "Dummy Token", "1", 0);
        tkn_ = address(tkn);

        TitleFab titlefab = new TitleFab();
        LightSwitchFab lightswitchfab = new LightSwitchFab();
        PileFab pilefab = new PileFab();
        ShelfFab shelffab = new ShelfFab();
        CollateralFab collateralfab = new CollateralFab();
        DeskFab deskfab = new DeskFab();
        AdmitFab admitfab = new AdmitFab();
        AdminFab adminfab = new AdminFab();
        appraiser = new Appraiser();

        manager = new ManagerUser(appraiser);
        manager_ = address(manager);

        deployer = new Deployer(manager_, titlefab, lightswitchfab, pilefab, shelffab, collateralfab, deskfab, admitfab, adminfab);

        appraiser.rely(manager_);
        appraiser.rely(address(deployer));

        deployer.deployLightSwitch();
        deployer.deployTitle("Tinlake Loan", "TLNT");
        deployer.deployCollateral();
        deployer.deployPile(tkn_);
        deployer.deployShelf(address(appraiser));
        deployer.deployValve();
        deployer.deployDesk();
        deployer.deployAdmit();
        deployer.deployAdmin(address(appraiser));
        deployer.deploy();

        borrower = new User(address(deployer.reception()),tkn_,address(deployer.collateral()));
        borrower_ = address(borrower);
        manager.file(deployer);

    }

    function setUp() public {
        basicSetup();
        lenderfab = address(new SimpleLenderFab());
        deployer.deployLender(tkn_, lenderfab);

    }


    // lenderTokenAddr returns the address which holds the currency or collateral token for the lender
    function lenderTokenAddr(address lender) public returns(address) {
        return lender;
    }

    // Checks
    function checkAfterBorrow(uint loan, uint tokenId, uint tBalance, uint cBalance) public {
        assertEq(tkn.balanceOf(borrower_), tBalance);
        assertEq(deployer.collateral().totalSupply(), cBalance);
        assertEq(deployer.collateral().balanceOf(lenderTokenAddr(address(deployer.lender()))), cBalance);
        assertEq(nft.ownerOf(tokenId), address(deployer.shelf()));
    }

    function checkAfterRepay(uint loan, uint tokenId, uint tTotal, uint cTotal, uint tLender) public {
        assertEq(nft.ownerOf(tokenId), borrower_);
        assertEq(deployer.pile().debtOf(loan), 0);
        assertEq(tkn.balanceOf(borrower_), tTotal-tLender);
        assertEq(tkn.balanceOf(address(deployer.pile())), 0);
        assertEq(tkn.balanceOf(lenderTokenAddr(address(deployer.lender()))), tLender);
        assertEq(deployer.collateral().balanceOf(address(deployer.desk())), 0);
        assertEq(deployer.collateral().totalSupply(), cTotal);
    }

    function whitelist(uint tokenId, address nft_, uint principal, uint appraisal, address borrower_, uint fee) public returns (uint) {
        // define fee
        manager.doInitFee(fee, fee);

        // nft whitelist
        uint loan = manager.doAdmit(nft_, tokenId, principal, appraisal, borrower_);

        // add fee for loan
        manager.doAddFee(loan, fee, 0);
        return loan;
    }

    function borrow(uint loan, uint tokenId, uint principal, uint appraisal) public {
        borrower.doApproveNFT(nft, address(deployer.shelf()));

        // borrow transaction
        borrower.doBorrow(loan);

        checkAfterBorrow(loan, tokenId, principal, appraisal);
    }


    function defaultLoan() public returns(uint tokenId, uint principal, uint appraisal, uint fee) {
        uint tokenId = 1;
        uint principal = 1000 ether;
        uint appraisal = 1200 ether;

        // define fee
        uint fee = uint(1000000564701133626865910626); // 5 % day

        return (tokenId, principal, appraisal, fee);
    }

    function setupOngoingLoan() public returns (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) {
        (uint tokenId, uint principal, uint appraisal, uint fee) = defaultLoan();

        // create borrower collateral nft
        nft.mint(borrower_, tokenId);

        uint loan = whitelist(tokenId, nft_, principal, appraisal, borrower_, fee);

        borrow(loan, tokenId, principal, appraisal);

        return (loan, tokenId, principal, appraisal, fee);
    }

    function setupRepayReq() public returns(uint) {
        // borrower needs some currency to pay fee
        uint extra = 100000000000 ether;
        tkn.mint(borrower_, extra);

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(deployer.pile()), uint(-1));

        return extra;
    }

    function currLenderBal() public returns(uint) {
        return tkn.balanceOf(lenderTokenAddr(address(deployer.lender())));
    }

    function borrowRepay(uint tokenId, uint principal, uint appraisal, uint fee) public {
        // create borrower collateral nft
        nft.mint(borrower_, tokenId);

        uint loan = whitelist(tokenId, nft_, principal, appraisal, borrower_, fee);

        borrow(loan, tokenId, principal, appraisal);

        hevm.warp(now + 10 days);

        // borrower needs some currency to pay fee
        uint extra = setupRepayReq();


        uint lenderShould = deployer.pile().burden(loan) + currLenderBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);

        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId,totalT , 0, lenderShould);

    }


    // --- Tests ---

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
        (uint tokenId, uint principal, uint appraisal, uint fee) = defaultLoan();
        borrowRepay(tokenId, principal, appraisal, fee);
    }



    function testMediumSizeLoans() public {
        (uint tokenId, uint principal, uint appraisal, uint fee) = defaultLoan();

        appraisal = 1200000 ether;
        principal = 1000000 ether;

        borrowRepay(tokenId, principal, appraisal, fee);

    }

    function testHighSizeLoans() public {
        (uint tokenId, uint principal, uint appraisal, uint fee) = defaultLoan();

        appraisal = 120000000 ether;
        principal = 100000000 ether; // 100 million

        borrowRepay(tokenId, principal, appraisal, fee);

    }

    function testRepayFullAmount() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) = setupOngoingLoan();

        hevm.warp(now + 1 days);

        // borrower needs some currency to pay fee
        uint extra = setupRepayReq();


        uint lenderShould = deployer.pile().burden(loan) + currLenderBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);

        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId,totalT , 0, lenderShould);

    }


    function testLongOngoing() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) = setupOngoingLoan();

        // interest 5% per day 1.05^300 ~ 2273996.1286 chi
        hevm.warp(now + 300 days);

        // borrower needs some currency to pay fee
        uint extra = setupRepayReq();

        uint lenderShould = deployer.pile().burden(loan) + currLenderBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);

        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId,totalT , 0, lenderShould);
    }

    function testMultipleBorrowAndRepay () public {
        uint principal = 100;
        uint appraisal = 120;

        uint cTotalSupply = 0;
        uint tBorrower = 0;

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
            tBorrower += principal;
            checkAfterBorrow(i, i, tBorrower,cTotalSupply);
        }

        // repay

        uint tTotal = tkn.totalSupply();

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(deployer.pile()), uint(-1));

        uint tLenderBalance = tkn.balanceOf(lenderTokenAddr(address(deployer.lender())));

        for (uint i = 0; i < 10; i++) {
            appraisal = (i+1)*100;
            principal = appraisal/100 * 80;

            // repay transaction
            borrower.doRepay(i, principal, borrower_);

            cTotalSupply -= appraisal;
            tLenderBalance += principal;

            checkAfterRepay(i,i,tTotal, cTotalSupply, tLenderBalance);
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

