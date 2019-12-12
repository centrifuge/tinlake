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

import "../../deployer.sol";
import "../../appraiser.sol";
import "../simple/nft.sol";
import "../simple/token.sol";

contract ERC20Like {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
    function totalSupply() public returns (uint256);
    function balanceOf(address usr) public returns (uint);
}

contract User {
    ERC20Like tkn;
    Pile pile;
    Shelf shelf;
    Desk desk;

    constructor (address pile_, address shelf_, address desk_, address tkn_) public {
        pile = Pile(pile_);
        shelf = Shelf(shelf_);
        desk = Desk(desk_);
        tkn = ERC20Like(tkn_);
    }

    function doBorrow (uint loan) public {
        shelf.deposit(loan, address(this));
        desk.balance();

//        // borrow max amount
        uint wad = pile.balanceOf(loan);
        pile.withdraw(loan, wad, address(this));
    }

    function doApproveNFT(SimpleNFT nft, address usr) public {
        nft.setApprovalForAll(usr, true);
    }

    function doRepay(uint loan, uint wad, address usr) public {
        pile.repay(loan, wad);
        shelf.release(loan, usr);
        desk.balance();
    }

    function doClose(uint loan, address usr) public {
        pile.collect(loan);
        uint debt = pile.debtOf(loan);
        doRepay(loan, debt, usr);
    }

    function doApproveCurrency(address usr, uint wad) public {
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

    function doInitFee(uint fee, uint speed) public {
        deployer.admin().file(fee, speed);
    }

    function doAddFee(uint loan, uint fee, uint balance) public {
        deployer.pile().file(loan, fee, balance);
    }
}

contract Hevm {
    function warp(uint256) public;
}

contract ShelfLike {
    function shelf(uint loan) public returns(address registry,uint256 tokenId,uint price,uint principal, uint initial);
}

contract SystemTest is DSTest {
    SimpleNFT    public nft;
    address      public nft_;
    SimpleToken  public tkn;
    address      public tkn_;
    Appraiser    appraiser;
    Deployer     public deployer;

    ManagerUser  manager;
    address      manager_;
    User borrower;
    address      borrower_;
    Hevm public hevm;

    function setUp() public {
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
        DeskFab deskfab = new DeskFab();
        AdmitFab admitfab = new AdmitFab();
        AdminFab adminfab = new AdminFab();
        BeansFab beansfab = new BeansFab();
        appraiser = new Appraiser();

        manager = new ManagerUser(appraiser);
        manager_ = address(manager);

        deployer = new Deployer(manager_, titlefab, lightswitchfab, pilefab, shelffab, deskfab, admitfab, adminfab, beansfab);

        appraiser.rely(manager_);
        appraiser.rely(address(deployer));

        deployer.deployLightSwitch();
        deployer.deployTitle("Tinlake Loan", "TLNT");
        deployer.deployBeans();
        deployer.deployPile(tkn_);
        deployer.deployShelf(address(appraiser));
        deployer.deployDesk(tkn_);
        deployer.deployAdmit();
        deployer.deployAdmin(address(appraiser));
        deployer.deploy();

        borrower = new User(address(deployer.pile()), address(deployer.shelf()), address(deployer.desk()), tkn_);
        borrower_ = address(borrower);
        manager.file(deployer);
    }

    // Checks
    function checkAfterBorrow(uint tokenId, uint tBalance) public {
        assertEq(tkn.balanceOf(borrower_), tBalance);
        assertEq(nft.ownerOf(tokenId), address(deployer.shelf()));
    }

    function checkAfterRepay(uint loan, uint tokenId, uint tTotal, uint tLender) public {
        assertEq(nft.ownerOf(tokenId), borrower_);
        assertEq(deployer.pile().debtOf(loan), 0);
        assertEq(tkn.balanceOf(borrower_), tTotal - tLender);
        assertEq(tkn.balanceOf(address(deployer.pile())), 0);
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

    function borrow(uint loan, uint tokenId, uint principal) public {
        borrower.doApproveNFT(nft, address(deployer.shelf()));

        // borrow transaction
        borrower.doBorrow(loan);
        checkAfterBorrow(tokenId, principal);
    }

    function defaultLoan() public pure returns(uint tokenId, uint principal, uint appraisal, uint fee) {
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
        borrow(loan, tokenId, principal);

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

    // note: this method will be refactored with the new lender side contracts, as the Desk should not hold any currency
    function currDeskBal() public returns(uint) {
        return tkn.balanceOf(address(deployer.desk()));
    }

    function borrowRepay(uint tokenId, uint principal, uint appraisal, uint fee) public {
        // create borrower collateral nft
        nft.mint(borrower_, tokenId);
        uint loan = whitelist(tokenId, nft_, principal, appraisal, borrower_, fee);

        ShelfLike shelf_ = ShelfLike(address(deployer.shelf()));
        ( , , , uint p_, uint i_) = shelf_.shelf(loan);
        assertEq(p_, i_);

        borrow(loan, tokenId, principal);

        ( , , , uint p2, uint i2) = shelf_.shelf(loan);
        assertEq(p2, 0);
        assertEq(i2, p_);

        hevm.warp(now + 10 days);

        // borrower needs some currency to pay fee
        setupRepayReq();
        uint deskShould = deployer.pile().burden(loan) + currDeskBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);
        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, deskShould);
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

        checkAfterBorrow(tokenId, principal);
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
        setupRepayReq();
        uint deskShould = deployer.pile().burden(loan) + currDeskBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);

        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, deskShould);
    }

    function testLongOngoing() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint fee) = setupOngoingLoan();

        // interest 5% per day 1.05^300 ~ 2273996.1286 chi
        hevm.warp(now + 300 days);

        // borrower needs some currency to pay fee
        setupRepayReq();

        uint deskShould = deployer.pile().burden(loan) + currDeskBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);

        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, deskShould);
    }

    function testMultipleBorrowAndRepay () public {
        uint principal = 100;
        uint appraisal = 120;

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
            tBorrower += principal;
            checkAfterBorrow(i, tBorrower);
        }

        // repay

        uint tTotal = tkn.totalSupply();

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(deployer.pile()), uint(-1));

        uint deskBalance = tkn.balanceOf(address(deployer.desk()));

        for (uint i = 0; i < 10; i++) {
            appraisal = (i+1)*100;
            principal = appraisal/100 * 80;

            // repay transaction
            borrower.doRepay(i, principal, borrower_);
            deskBalance += principal;
            checkAfterRepay(i, i, tTotal, deskBalance);
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
        checkAfterBorrow(tokenId, principal);

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
