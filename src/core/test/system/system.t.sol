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

contract User is DSTest{
    ERC20Like tkn;
    Shelf shelf;
    Desk desk;
    Pile pile;

    constructor (address shelf_, address desk_, address tkn_, address pile_) public {
        shelf = Shelf(shelf_);
        desk = Desk(desk_);
        tkn = ERC20Like(tkn_);
        pile = Pile(pile_);
    }

    function doBorrow(uint loan, uint amount) public {
        shelf.lock(loan, address(this));
        shelf.borrow(loan, amount);
        desk.balance();
        shelf.withdraw(loan, amount, address(this));
    }

    function doApproveNFT(SimpleNFT nft, address usr) public {
        nft.setApprovalForAll(usr, true);
    }

    function doRepay(uint loan, uint wad, address usr) public {
        emit log_named_uint("loan", wad);
        shelf.repay(loan, wad);
         emit log_named_uint("loan", wad);
        shelf.unlock(loan);
         emit log_named_uint("loan", wad);
        desk.balance();
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

    function doInitRate(uint rate, uint speed) public {
        deployer.admin().file(rate, speed);
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

    // appraisal -- dominated in WAD
    function doUpdateAppraisal(uint loan, uint appraisal) public {
        appraiser.file(loan, appraisal);
    }
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

contract SystemTest is DSTest {
    SimpleNFT    public nft;
    address      public nft_;
    SimpleToken  public tkn;
    address      public tkn_;
    Appraiser    appraiser;
    Deployer     public deployer;

    AdminUser public  admin;
    address      admin_;
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
        ShelfFab shelffab = new ShelfFab();
        DeskFab deskfab = new DeskFab();
        AdmitFab admitfab = new AdmitFab();
        AdminFab adminfab = new AdminFab();
        PileFab pileFab = new PileFab();
        PrincipalFab principalFab = new PrincipalFab();
        appraiser = new Appraiser();

        admin = new AdminUser(appraiser);
        admin_ = address(admin);
        deployer = new Deployer(admin_, titlefab, lightswitchfab, shelffab, deskfab, admitfab, adminfab, pileFab, principalFab);

        appraiser.rely(admin_);
        appraiser.rely(address(deployer));
         
        deployer.deployLightSwitch();
        deployer.deployTitle("Tinlake Loan", "TLNT");
        deployer.deployPile();
        deployer.deployPrincipal();
        deployer.deployShelf(tkn_);
        deployer.deployDesk(tkn_);
        deployer.deployAdmit();
        deployer.deployAdmin(address(appraiser));

        deployCollect();

        deployer.deploy();

        borrower = new User(address(deployer.shelf()), address(deployer.desk()), tkn_, address(deployer.pile()));
        borrower_ = address(borrower);
        admin.file(deployer);

    }

    function deployCollect() public {
        CollectorFab collectorFab = new CollectorFab();
        // TODO
    }

    // Checks
    function checkAfterBorrow(uint tokenId, uint tBalance) public {
        assertEq(tkn.balanceOf(borrower_), tBalance);
        assertEq(nft.ownerOf(tokenId), address(deployer.shelf()));
    }

    function checkAfterRepay(uint loan, uint tokenId, uint tTotal, uint tLender) public {
        assertEq(nft.ownerOf(tokenId), borrower_);
        assertEq(deployer.pile().debt(loan), 0);
        assertEq(tkn.balanceOf(borrower_), tTotal - tLender);
        assertEq(tkn.balanceOf(address(deployer.pile())), 0);
    }

    function whitelist(uint tokenId, address nft_, uint principal, uint appraisal, address borrower_, uint rate) public returns (uint) {
        // define rate
        admin.doInitRate(rate, rate);
        // nft whitelist
        uint loan = admin.doAdmit(nft_, tokenId, principal, appraisal, borrower_);
        
        // add rate for loan
        admin.doAddRate(loan, rate);
        return loan;
    }

    function borrow(uint loan, uint tokenId, uint principal) public {
        borrower.doApproveNFT(nft, address(deployer.shelf()));

        // borrow transaction
        borrower.doBorrow(loan, principal);
        checkAfterBorrow(tokenId, principal);
    }

    function defaultLoan() public pure returns(uint tokenId, uint principal, uint appraisal, uint rate) {
        uint tokenId = 1;
        uint principal = 1000 ether;
        uint appraisal = 1200 ether;
        // define rate
        uint rate = uint(1000000564701133626865910626); // 5 % day

        return (tokenId, principal, appraisal, rate);
    }

    function setupOngoingLoan() public returns (uint loan, uint tokenId, uint principal, uint appraisal, uint rate) {
        (uint tokenId, uint principal, uint appraisal, uint rate) = defaultLoan();
        // create borrower collateral nft
        nft.mint(borrower_, tokenId);
        uint loan = whitelist(tokenId, nft_, principal, appraisal, borrower_, rate);
        borrow(loan, tokenId, principal);

        return (loan, tokenId, principal, appraisal, rate);
    }

    function setupRepayReq() public returns(uint) {
        // borrower needs some currency to pay rate
        uint extra = 100000000000 ether;
        tkn.mint(borrower_, extra);

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(deployer.shelf()), uint(-1));

        return extra;
    }

    // note: this method will be refactored with the new lender side contracts, as the Desk should not hold any currency
    function currDeskBal() public returns(uint) {
        return tkn.balanceOf(address(deployer.desk()));
    }

    function borrowRepay(uint tokenId, uint principal, uint appraisal, uint rate) public {
        ShelfLike shelf_ = ShelfLike(address(deployer.shelf()));
        CeilingLike ceiling_ = CeilingLike(address(deployer.principal()));
        
        // create borrower collateral nft
        nft.mint(borrower_, tokenId);
        uint loan = whitelist(tokenId, nft_, principal, appraisal, borrower_, rate);
    
        assertEq(ceiling_.values(loan), principal);
        borrow(loan, tokenId, principal);


        assertEq(ceiling_.values(loan), 0);

        hevm.warp(now + 10 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint deskShould = deployer.pile().debt(loan) + currDeskBal();
       
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
        uint loan = admin.doAdmit(nft_, tokenId, principal, appraisal, borrower_);
        borrower.doApproveNFT(nft, address(deployer.shelf()));
        borrower.doBorrow(loan, principal);

        checkAfterBorrow(tokenId, principal);
    }

    function testBorrowAndRepay() public {
        (uint tokenId, uint principal, uint appraisal, uint rate) = defaultLoan();
        borrowRepay(tokenId, principal, appraisal, rate);
    }


    function testMediumSizeLoans() public {
        (uint tokenId, uint principal, uint appraisal, uint rate) = defaultLoan();

        appraisal = 1200000 ether;
        principal = 1000000 ether;

        borrowRepay(tokenId, principal, appraisal, rate);
    }

    function testHighSizeLoans() public {
        (uint tokenId, uint principal, uint appraisal, uint rate) = defaultLoan();
        appraisal = 120000000 ether;
        principal = 100000000 ether; // 100 million

        borrowRepay(tokenId, principal, appraisal, rate);
    }

    function testRepayFullAmount() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint rate) = setupOngoingLoan();

        hevm.warp(now + 1 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint deskShould = deployer.pile().debt(loan) + currDeskBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);

        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, deskShould);
    }

    function testLongOngoing() public {
        (uint loan, uint tokenId, uint principal, uint appraisal, uint rate) = setupOngoingLoan();

        // interest 5% per day 1.05^300 ~ 2273996.1286 chi
        hevm.warp(now + 300 days);

        // borrower needs some currency to pay rate
        setupRepayReq();

        uint deskShould = deployer.pile().debt(loan) + currDeskBal();

        // close without defined amount
        borrower.doClose(loan, borrower_);

        uint totalT = uint(tkn.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, deskShould);
    }

    function testMultipleBorrowAndRepay () public {
        uint principal = 100;
        uint appraisal = 120;
        uint rate = uint(1000000564701133626865910626);

        uint tBorrower = 0;
        uint tokenId;
        // borrow
        for (uint i = 1; i <= 10; i++) {
            
            tokenId = i;
            appraisal = (i)*100;
            principal = appraisal/100 * 80;

            // create borrower collateral nft
            nft.mint(borrower_, tokenId);
            uint loan = whitelist(tokenId, nft_, principal, appraisal, borrower_, rate);
            // nft whitelist
        
            borrower.doApproveNFT(nft, address(deployer.shelf()));
            borrower.doBorrow(loan, principal);
            tBorrower += principal;
            emit log_named_uint("total", tBorrower);
            checkAfterBorrow(i, tBorrower);
        }

        // repay
        uint tTotal = tkn.totalSupply();

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(deployer.shelf()), uint(-1));

        uint deskBalance = tkn.balanceOf(address(deployer.desk()));
        for (uint i = 1; i <= 10; i++) {
            appraisal = i*100;
            principal = appraisal/100 * 80;

            // repay transaction
            emit log_named_uint("repay", principal);
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
        uint loan = admin.doAdmit(nft_, tokenId, principal, appraisal, borrower_);
        borrower.doApproveNFT(nft, address(deployer.shelf()));
        borrower.doBorrow(loan, principal);
        checkAfterBorrow(tokenId, principal);

        // should fail
        borrower.doBorrow(loan, principal);
    }

    function testFailBorrowNonExistingToken() public {
        borrower.doBorrow(42, 100);
        assertEq(tkn.balanceOf(borrower_), 0);
    }

    function testFailBorrowNotWhitelisted() public {
        uint nft_tokenId = 1;
        nft.mint(borrower_, nft_tokenId);
        borrower.doBorrow(1, 100);
        assertEq(tkn.balanceOf(borrower_), 0);
    }

    function testFailAdmitNonExistingNFT() public {
        uint loan = admin.doAdmit(nft_, 1, 100, 120, borrower_);
        borrower.doBorrow(loan, 100);
        assertEq(tkn.balanceOf(borrower_), 0);
    }

    function testFailBorrowNFTNotApproved() public {
        uint nft_tokenId = 1;
        nft.mint(borrower_, nft_tokenId);
        uint loan = admin.doAdmit(nft_, nft_tokenId, 100, 120, borrower_);
        borrower.doBorrow(loan, 100);
        assertEq(tkn.balanceOf(borrower_), 100);
    }
}
