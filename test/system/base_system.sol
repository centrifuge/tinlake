// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "./setup.sol";
import "./users/admin.sol";
import "./users/investor.sol";
import "./users/borrower.sol";
import {BaseTypes} from "test/lender/coordinator-base.t.sol";
import "./assertions.sol";

contract BaseSystemTest is TestSetup, BaseTypes, Math, Assertions {
    // users
    Borrower borrower;
    address borrower_;

    AdminUser public admin;
    address admin_;

    Borrower randomUser;
    address randomUser_;

    Investor seniorInvestor;
    address seniorInvestor_;
    Investor juniorInvestor;
    address juniorInvestor_;
    NAVFeedLike navFeed_;

    Hevm hevm;

    uint256 public constant DEFAULT_RISK_GROUP_TEST_LOANS = 3;
    uint256 public constant DEFAULT_FUND_BORROWER = 1000 ether;
    uint256 public constant DEFAULT_HIGH_FUND_BORROWER = 100000000000 ether;
    uint256 public constant DEFAULT_NFT_PRICE = 100;

    uint256 public constant DEFAULT_SENIOR_RATIO = 82 * 10 ** 25;
    uint256 public constant DEFAULT_JUNIOR_RATIO = 18 * 10 ** 25;

    function baseSetup() public {
        deployContracts();
    }

    function createTestUsers() public {
        borrower = new Borrower(address(shelf), address(reserve), currency_, address(pile));
        borrower_ = address(borrower);
        randomUser = new Borrower(address(shelf), address(reserve), currency_, address(pile));
        randomUser_ = address(randomUser);
        admin =
        new AdminUser(address(shelf), address(pile), address(nftFeed), address(title), address(reserve), address(juniorMemberlist), address(seniorMemberlist));
        admin_ = address(admin);
        root.relyBorrowerAdmin(admin_);
        root.relyLenderAdmin(admin_);
        createInvestorUser();
                initNAV();
    }

    function initNAV() public {
         // The following score cards just examples that are mostly optimized for the system test cases
        admin.fileRisk(
            0,                                      // riskGroup:       0
            8*10**26,                               // thresholdRatio   80%
            6*10**26,                               // ceilingRatio     60%
            ONE                                     // interestRate     1.0
        );

        admin.fileRisk(
            1,                                      // riskGroup:       1
            7*10**26,                               // thresholdRatio   70%
            5*10**26,                               // ceilingRatio     50%
            uint(1000000003593629043335673583)      // interestRate     12% per year
        );

        admin.fileRisk(
            2,                                      // riskGroup:       2
            7*10**26,                               // thresholdRatio   70%
            5*10**26,                               // ceilingRatio     50%
            uint(1000000564701133626865910626)      // interestRate     5% per day
        );

         admin.fileRisk(
            3,                                      // riskGroup:       3
            7*10**26,                               // thresholdRatio   70%
            ONE,                                    // ceilingRatio     100%
            uint(1000000564701133626865910626)      // interestRate     5% per day
        );

         admin.fileRisk(
            4,                                      // riskGroup:       4
            5*10**26,                               // thresholdRatio   50%
            6*10**26,                               // ceilingRatio     60%
            uint(1000000564701133626865910626)      // interestRate     5% per day
        );
    }

    function createInvestorUser() public {
        seniorInvestor = new Investor(address(seniorOperator), address(seniorTranche), currency_, address(seniorToken));
        seniorInvestor_ = address(seniorInvestor);
        juniorInvestor = new Investor(address(juniorOperator), address(juniorTranche), currency_, address(juniorToken));
        juniorInvestor_ = address(juniorInvestor);
    }

    function lockNFT(uint256 loanId, address usr) public {
        Borrower(usr).approveNFT(collateralNFT, address(shelf));
        Borrower(usr).lock(loanId);
    }

    function transferNFT(address sender, address recipient, uint256 tokenId) public {
        Borrower(sender).approveNFT(collateralNFT, address(this));
        collateralNFT.transferFrom(sender, recipient, tokenId);
    }

    function issueNFT(address usr) public override returns (uint256 tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function computeCeiling(uint256 riskGroup, uint256 nftPrice) public view returns (uint256) {
        uint256 ceilingRatio = nftFeed.ceilingRatio(riskGroup);
        return rmul(ceilingRatio, nftPrice);
    }

    function getRateByRisk(uint256 riskGroup) public view returns (uint256) {
        (,, uint256 ratePerSecond,,) = pile.rates(riskGroup);
        return ratePerSecond;
    }

    function issueNFTAndCreateLoan(address usr) public returns (uint256, uint256) {
        // issue nft for borrower
        (uint256 tokenId,) = issueNFT(usr);
        // issue loan for borrower
        uint256 loanId = Borrower(usr).issue(collateralNFT_, tokenId);
        return (tokenId, loanId);
    }

    function priceNFTandSetRisk(uint256 tokenId, uint256 nftPrice, uint256 riskGroup) public {
        uint256 maturityDate = 600 days;
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup, maturityDate);
    }

    function priceNFTandSetRisk(uint256 tokenId, uint256 nftPrice, uint256 riskGroup, uint256 maturityDate) public {
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        admin.priceNFTAndSetRiskGroup(lookupId, nftPrice, riskGroup, maturityDate);
    }

    function priceNFT(uint256 tokenId, uint256 nftPrice) public {
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        admin.priceNFT(lookupId, nftPrice);
    }

    function createLoanAndBorrow(address usr, uint256 nftPrice, uint256 riskGroup) public returns (uint256, uint256) {
        (uint256 loanId, uint256 tokenId) = issueNFTAndCreateLoan(usr);

        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // lock nft
        lockNFT(loanId, usr);

        // compute ceiling based on nftPrice & riskgroup
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        //borrow
        Borrower(usr).borrow(loanId, ceiling);
        return (loanId, tokenId);
    }

    function createLoanAndWithdraw(address usr, uint256 nftPrice, uint256 riskGroup)
        public
        returns (uint256, uint256)
    {
        (uint256 loanId, uint256 tokenId) = createLoanAndBorrow(usr, nftPrice, riskGroup);
        uint256 ceiling = computeCeiling(riskGroup, nftPrice);
        Borrower(usr).withdraw(loanId, ceiling, borrower_);
        return (loanId, tokenId);
    }

    function repayLoan(address usr, uint256 loanId, uint256 currencyAmount) public {
        // transfer extra funds, so that usr can pay for interest
        currency.mint(address(usr), currencyAmount);
        // borrower allows shelf full control over borrower tokens
        Borrower(usr).doApproveCurrency(address(shelf), type(uint256).max);
        // repay loan
        borrower.repay(loanId, currencyAmount);
    }

    // helpers lenders
    function defaultInvest(uint256 currencyAmount) public {
        uint256 validUntil = safeAdd(block.timestamp, 8 days);
        admin.makeJuniorTokenMember(juniorInvestor_, validUntil);
        admin.makeSeniorTokenMember(seniorInvestor_, validUntil);

        uint256 amountSenior = rmul(currencyAmount, DEFAULT_SENIOR_RATIO);
        uint256 amountJunior = rmul(currencyAmount, DEFAULT_JUNIOR_RATIO);

        currency.mint(seniorInvestor_, amountSenior);
        currency.mint(juniorInvestor_, amountJunior);

        seniorInvestor.supplyOrder(amountSenior);
        juniorInvestor.supplyOrder(amountJunior);
    }

    function setupCurrencyOnLender(uint256 amount) public {
        defaultInvest(amount);
    }

    function supplyFunds(uint256 amount, address addr) public {
        currency.mint(address(addr), amount);
    }

    function topUp(address usr) public {
        currency.mint(address(usr), DEFAULT_FUND_BORROWER);
    }

    function setupOngoingLoan(uint256 nftPrice, uint256 borrowAmount, bool lenderFundingRequired, uint256 maturityDate)
        public
        returns (uint256 loan, uint256 tokenId)
    {
        // default risk group for system tests
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, DEFAULT_RISK_GROUP_TEST_LOANS, maturityDate);
        borrow(loan, tokenId, borrowAmount, lenderFundingRequired);
        return (loan, tokenId);
    }

    function setupOngoingLoan(uint256 nftPrice, uint256 borrowAmount, uint256 maturityDate)
        public
        returns (uint256 loan, uint256 tokenId)
    {
        // default risk group for system tests
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, DEFAULT_RISK_GROUP_TEST_LOANS, maturityDate);
        borrower.approveNFT(collateralNFT, address(shelf));

        uint256 preBalance = currency.balanceOf(borrower_);
        borrower.borrowAction(loan, borrowAmount);

        assertEq(currency.balanceOf(borrower_), borrowAmount + preBalance);
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        return (loan, tokenId);
    }

    function setupOngoingLoan() public returns (uint256 loan, uint256 tokenId, uint256 ceiling) {
        (uint256 nftPrice, uint256 riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
        // borrow max amount possible
        uint256 ceiling_ = navFeed_.ceiling(loan);
        borrow(loan, tokenId, ceiling_);
        return (loan, tokenId, ceiling_);
    }

    function setupLoan(uint256 tokenId, address collateralNFT_, uint256 nftPrice, uint256 riskGroup)
        public
        returns (uint256)
    {
        uint256 maturityDate = block.timestamp + 600 days;
        return setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup, maturityDate);
    }

    function setupLoan(
        uint256 tokenId,
        address collateralNFT_,
        uint256 nftPrice,
        uint256 riskGroup,
        uint256 maturityDate
    ) public returns (uint256) {
        // borrower issue loans
        uint256 loan = borrower.issue(collateralNFT_, tokenId);
        // price collateral and add to riskgroup
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup, maturityDate);
        return loan;
    }

    function fundLender(uint256 amount) public {
        defaultInvest(amount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
    }

    function borrow(uint256 loan, uint256 tokenId, uint256 borrowAmount) public {
        borrow(loan, tokenId, borrowAmount, true);
    }

    function borrow(uint256 loan, uint256 tokenId, uint256 borrowAmount, bool fundLenderRequired) public {
        uint preBalance = currency.balanceOf(borrower_);
        borrower.approveNFT(collateralNFT, address(shelf));
        if (fundLenderRequired) {
            fundLender(borrowAmount);
        }
        borrower.borrowAction(loan, borrowAmount);
        checkAfterBorrow(tokenId, borrowAmount, preBalance);
    }

    function defaultCollateral() public pure returns (uint256 nftPrice_, uint256 riskGroup_) {
        return (DEFAULT_NFT_PRICE, DEFAULT_RISK_GROUP_TEST_LOANS);
    }

    // note: this method will be refactored with the new lender side contracts, as the reserve should not hold any currency
    function currReserveBalance() public view returns (uint256) {
        return currency.balanceOf(address(reserve));
    }

    // Checks
    function checkAfterBorrow(uint tokenId, uint tBalance, uint preBalance) public {
        assertEq(currency.balanceOf(borrower_), safeAdd(preBalance, tBalance));
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
    }

    function checkAfterRepay(uint256 loan, uint256 tokenId, uint256 tTotal, uint256 tLender) public {
        assertEq(collateralNFT.ownerOf(tokenId), borrower_);
        assertEq(pile.debt(loan), 0);
        assertEq(currency.balanceOf(borrower_), safeSub(tTotal, tLender));
        assertEq(currency.balanceOf(address(pile)), 0);
    }

    function borrowRepay(uint256 nftPrice, uint256 riskGroup) public {
        // create borrower collateral collateralNFT
        uint256 tokenId = collateralNFT.issue(borrower_);
        uint256 loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
        uint256 ceiling = navFeed_.ceiling(loan);

        borrow(loan, tokenId, ceiling);

        hevm.warp(block.timestamp + 10 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint256 reserveShould = pile.debt(loan) + currReserveBalance();
        // close without defined amount
        borrower.doClose(loan);
        uint256 totalT = uint256(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, reserveShould);
    }

    function fixed18To27(uint256 valPower18) public pure returns (uint256) {
        // convert 10^18 to 10^27
        return valPower18 * 10 ** 9;
    }

    function setupRepayReq() public returns (uint256) {
        // borrower needs some currency to pay rate
        currency.mint(borrower_, DEFAULT_HIGH_FUND_BORROWER);
        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);
        return DEFAULT_HIGH_FUND_BORROWER;
    }
}
