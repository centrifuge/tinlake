// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "./setup.sol";

import "./users/admin.sol";
import "./users/investor.sol";
import "./users/borrower.sol";
import "./users/keeper.sol";
import "tinlake-math/math.sol";
import {BaseTypes} from "../../lender/test/coordinator-base.t.sol";
import "./assertions.sol";

contract BaseSystemTest is TestSetup, BaseTypes, Math, Assertions {
    // users
    Borrower borrower;
    address borrower_;

    AdminUser public admin;
    address admin_;

    Borrower randomUser;
    address randomUser_;

    Keeper keeper;
    address keeper_;

    Investor seniorInvestor;
    address  seniorInvestor_;
    Investor juniorInvestor;
    address  juniorInvestor_;
    NFTFeedLike nftFeed_;

    Hevm hevm;

    uint constant public DEFAULT_RISK_GROUP_TEST_LOANS = 3;
    uint constant public DEFAULT_FUND_BORROWER = 1000 ether;
    uint constant public DEFAULT_HIGH_FUND_BORROWER = 100000000000 ether;
    uint constant public DEFAULT_NFT_PRICE = 100;

    uint constant public DEFAULT_SENIOR_RATIO = 82 * 10**25;
    uint constant public DEFAULT_JUNIOR_RATIO = 18 * 10**25;

    function baseSetup() public {
        deployContracts();
    }

    function createTestUsers() public {
        borrower = new Borrower(address(shelf), address(reserve), currency_, address(pile));
        borrower_ = address(borrower);
        randomUser = new Borrower(address(shelf), address(reserve), currency_, address(pile));
        randomUser_ = address(randomUser);
        keeper = new Keeper(address(collector), currency_);
        keeper_ = address(keeper);
        admin = new AdminUser(address(shelf), address(pile), address(nftFeed), address(title), address(reserve), address(collector), address(juniorMemberlist), address(seniorMemberlist));
        admin_ = address(admin);
        root.relyBorrowerAdmin(admin_);
        root.relyLenderAdmin(admin_);
        createInvestorUser();
    }

    function createInvestorUser() public {
        seniorInvestor = new Investor(address(seniorOperator), address(seniorTranche), currency_, address(seniorToken));
        seniorInvestor_ = address(seniorInvestor);
        juniorInvestor = new Investor(address(juniorOperator), address(juniorTranche), currency_, address(juniorToken));
        juniorInvestor_ = address(juniorInvestor);
    }

    function lockNFT(uint loanId, address usr) public {
        Borrower(usr).approveNFT(collateralNFT, address(shelf));
        Borrower(usr).lock(loanId);
    }

    function transferNFT(address sender, address recipient, uint tokenId) public {
        Borrower(sender).approveNFT(collateralNFT, address(this));
        collateralNFT.transferFrom(sender, recipient, tokenId);
    }

    function issueNFT(address usr) public override returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function computeCeiling(uint riskGroup, uint nftPrice) public view returns (uint) {
        uint ceilingRatio = nftFeed.ceilingRatio(riskGroup);
        return rmul(ceilingRatio, nftPrice);
    }

    function getRateByRisk(uint riskGroup) public view returns (uint) {
        (,,uint ratePerSecond,,) = pile.rates(riskGroup);
        return ratePerSecond;
    }

    function issueNFTAndCreateLoan(address usr) public returns (uint, uint) {
        // issue nft for borrower
        (uint tokenId, ) = issueNFT(usr);
        // issue loan for borrower
        uint loanId = Borrower(usr).issue(collateralNFT_, tokenId);
        return (tokenId, loanId);
    }

    function priceNFTandSetRisk(uint tokenId, uint nftPrice, uint riskGroup) public {
        uint maturityDate = 600 days;
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup, maturityDate);
    }

    function priceNFTandSetRisk(uint tokenId, uint nftPrice, uint riskGroup, uint maturityDate) public {
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        admin.priceNFTAndSetRiskGroup(lookupId, nftPrice, riskGroup, maturityDate);
    }

    function priceNFT(uint tokenId, uint nftPrice) public {
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        admin.priceNFT(lookupId, nftPrice);
    }

    function createLoanAndBorrow(address usr, uint nftPrice, uint riskGroup) public returns (uint, uint) {
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(usr);

        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // lock nft
        lockNFT(loanId, usr);

        // compute ceiling based on nftPrice & riskgroup
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        //borrow
        Borrower(usr).borrow(loanId, ceiling);
        return (loanId, tokenId);
    }

    function createLoanAndWithdraw(address usr, uint nftPrice, uint riskGroup) public returns (uint, uint) {
        (uint loanId, uint tokenId) = createLoanAndBorrow(usr, nftPrice, riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        Borrower(usr).withdraw(loanId, ceiling, borrower_);
        return (loanId, tokenId);
    }

    function repayLoan(address usr, uint loanId, uint currencyAmount) public {
        // transfer extra funds, so that usr can pay for interest
        topUp(usr);
        // borrower allows shelf full control over borrower tokens
        Borrower(usr).doApproveCurrency(address(shelf), uint(-1));
        // repay loan
        borrower.repay(loanId, currencyAmount);
    }

    // helpers lenders
    function defaultInvest(uint currencyAmount) public {
        uint validUntil = safeAdd(now, 8 days);
        admin.makeJuniorTokenMember(juniorInvestor_, validUntil);
        admin.makeSeniorTokenMember(seniorInvestor_, validUntil);

        uint amountSenior = rmul(currencyAmount, DEFAULT_SENIOR_RATIO);
        uint amountJunior = rmul(currencyAmount, DEFAULT_JUNIOR_RATIO);

        currency.mint(seniorInvestor_, amountSenior);
        currency.mint(juniorInvestor_, amountJunior);

        seniorInvestor.supplyOrder(amountSenior);
        juniorInvestor.supplyOrder(amountJunior);
    }

    // helpers keeper
    function seize(uint loanId) public {
        collector.seize(loanId);
    }

    function addKeeperAndCollect(uint loanId, address usr, uint recoveryPrice) public {
        seize(loanId);
        admin.addKeeper(loanId, usr, recoveryPrice);
        topUp(usr);
        Borrower(usr).doApproveCurrency(address(shelf), uint(-1));
        admin.collect(loanId, usr);
    }

    function setupCurrencyOnLender(uint amount) public {
        defaultInvest(amount);
    }

    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(addr), amount);
    }
    function topUp(address usr) public {
        currency.mint(address(usr), DEFAULT_FUND_BORROWER);
    }

    function setupOngoingLoan(uint nftPrice, uint borrowAmount, bool lenderFundingRequired, uint maturityDate) public returns (uint loan, uint tokenId) {
        // default risk group for system tests
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, DEFAULT_RISK_GROUP_TEST_LOANS, maturityDate);
        borrow(loan, tokenId, borrowAmount, lenderFundingRequired);
        return (loan, tokenId);
    }

    function setupOngoingLoan(uint nftPrice, uint borrowAmount, uint maturityDate) public returns (uint loan, uint tokenId) {
        // default risk group for system tests
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, DEFAULT_RISK_GROUP_TEST_LOANS, maturityDate);
        borrower.approveNFT(collateralNFT, address(shelf));

        uint preBalance = currency.balanceOf(borrower_);
        borrower.borrowAction(loan, borrowAmount);

        assertEq(currency.balanceOf(borrower_), borrowAmount + preBalance);
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        return (loan, tokenId);
    }

    function setupOngoingLoan() public returns (uint loan, uint tokenId, uint ceiling) {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
        // borrow max amount possible
        uint ceiling_ = nftFeed_.ceiling(loan);
        borrow(loan, tokenId, ceiling_);
        return (loan, tokenId, ceiling_);
    }

    function setupLoan(uint tokenId, address collateralNFT_, uint nftPrice, uint riskGroup) public returns (uint) {
        uint maturityDate = now + 600 days;
        return setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup, maturityDate);
    }

    function setupLoan(uint tokenId, address collateralNFT_, uint nftPrice, uint riskGroup, uint maturityDate) public returns (uint) {
        // borrower issue loans
        uint loan = borrower.issue(collateralNFT_, tokenId);
        // price collateral and add to riskgroup
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup, maturityDate);
        return loan;
    }

    function fundLender(uint amount) public {
        defaultInvest(amount);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();
    }

    function borrow(uint loan, uint tokenId, uint borrowAmount) public {
        borrow(loan, tokenId, borrowAmount, true);
    }

    function borrow(uint loan, uint tokenId, uint borrowAmount, bool fundLenderRequired) public {
        borrower.approveNFT(collateralNFT, address(shelf));
        if (fundLenderRequired) {
            fundLender(borrowAmount);

        }
        borrower.borrowAction(loan, borrowAmount);
        checkAfterBorrow(tokenId, borrowAmount);
    }

    function defaultCollateral() public pure returns(uint nftPrice_, uint riskGroup_) {
        return (DEFAULT_NFT_PRICE, DEFAULT_RISK_GROUP_TEST_LOANS);
    }

    // note: this method will be refactored with the new lender side contracts, as the reserve should not hold any currency
    function currReserveBalance() public view returns(uint) {
        return currency.balanceOf(address(reserve));
    }

    // Checks
    function checkAfterBorrow(uint tokenId, uint tBalance) public {
        assertEq(currency.balanceOf(borrower_), tBalance);
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
    }

    function checkAfterRepay(uint loan, uint tokenId, uint tTotal, uint tLender) public {
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
        assertEq(pile.debt(loan), 0);
        assertEq(currency.balanceOf(borrower_), safeSub(tTotal, tLender));
        assertEq(currency.balanceOf(address(pile)), 0);
    }

    function borrowRepay(uint nftPrice, uint riskGroup) public {
        // create borrower collateral collateralNFT
        uint tokenId = collateralNFT.issue(borrower_);
        uint loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
        uint ceiling = nftFeed_.ceiling(loan);

        assertEq(nftFeed_.ceiling(loan), ceiling);
        borrow(loan, tokenId, ceiling);
        assertEq(nftFeed_.ceiling(loan), 0);

        hevm.warp(now + 10 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint reserveShould = pile.debt(loan) + currReserveBalance();
        // close without defined amount
        borrower.doClose(loan);
        uint totalT = uint(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, reserveShould);
    }

    function fixed18To27(uint valPower18) public pure returns(uint) {
        // convert 10^18 to 10^27
        return valPower18 * 10**9;
    }

    function setupRepayReq() public returns(uint) {
        // borrower needs some currency to pay rate
        currency.mint(borrower_, DEFAULT_HIGH_FUND_BORROWER);
        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));
        return DEFAULT_HIGH_FUND_BORROWER;
    }
}
