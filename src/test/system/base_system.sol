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

import "ds-test/test.sol";
import "./setup.sol";

import "./users/admin.sol";
import "./users/investor.sol";
import "./users/borrower.sol";
import "./users/keeper.sol";
import "tinlake-math/math.sol";


contract BaseSystemTest is TestSetup, Math, DSTest {
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

    Hevm public hevm;

    function baseSetup() public {
        // setup deployment
        bytes32 feed_ = "nav";
        deployContracts(feed_);
    }

    function baseSetup(bytes32 feed_) public {
        deployContracts(feed_);
    }

    function createTestUsers() public {
        createTestUsers(true);
    }
    function createTestUsers(bool senior_) public {
        borrower = new Borrower(address(shelf), address(lenderDeployer.reserve()), currency_, address(pile));
        borrower_ = address(borrower);
        randomUser = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        randomUser_ = address(randomUser);
        keeper = new Keeper(address(collector), currency_);
        keeper_ = address(keeper);
        admin = new AdminUser(address(shelf), address(pile), address(nftFeed), address(title), address(distributor), address(collector), address(juniorMemberlist), address(seniorMemberlist));
        admin_ = address(admin);
        root.relyBorrowerAdmin(admin_);
        root.relyLenderAdmin(admin_);
        createInvestorUser();
    }

    function createInvestorUser() public {
        // investors
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

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        tokenId = collateralNFT.issue(usr);
        lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function computeCeiling(uint riskGroup, uint nftPrice) public returns (uint) {
        uint ceilingRatio = nftFeed.ceilingRatio(riskGroup);
        return rmul(ceilingRatio, nftPrice);
    }

    function getRateByRisk(uint riskGroup) public returns (uint) {
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
    function invest(uint currencyAmount) public {
        uint validUntil = safeAdd(now, 8 days);
        admin.makeJuniorTokenMember(juniorInvestor_, validUntil);
        admin.makeSeniorTokenMember(seniorInvestor_, validUntil);

        uint amountSenior = rmul(currencyAmount, 82 * 10**25);
        uint amountJunior = rmul(currencyAmount, 18 * 10**25);

        currency.mint(seniorInvestor_, amountSenior);
        currency.mint(juniorInvestor_, amountJunior);

        seniorInvestor.supplyOrder(amountSenior);
        juniorInvestor.supplyOrder(amountJunior);
    }

    // helpers keeper

    function seize(uint loanId) public {
        collector.seize(loanId);
    }

    function addKeeperAndCollect(uint loanId, uint threshold, address usr, uint recoveryPrice) public {
        seize(loanId);
        admin.addKeeper(loanId, usr, recoveryPrice);
        topUp(usr);
        Borrower(usr).doApproveCurrency(address(shelf), uint(-1));
        admin.collect(loanId, usr);
    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        invest(defaultAmount);

    }

    function setupCurrencyOnLender(uint amount) public {
        invest(amount);
    }

    function supplyFunds(uint amount, address addr) public {
        currency.mint(address(addr), amount);
    }
    function topUp(address usr) public {
        currency.mint(address(usr), 1000 ether);
    }

    function setupOngoingLoan(uint nftPrice, uint borrowAmount, bool lenderFundingRequired, uint maturityDate) public returns (uint loan, uint tokenId) {
        // default risk group for system tests
        uint riskGroup = 3;

        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup, maturityDate);
        uint ceiling = nftFeed_.ceiling(loan);
        borrow(loan, tokenId, borrowAmount, lenderFundingRequired);
        return (loan, tokenId);
    }

    function setupOngoingLoan() public returns (uint loan, uint tokenId, uint ceiling) {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        tokenId = collateralNFT.issue(borrower_);
        loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
        uint ceiling = nftFeed_.ceiling(loan);

        borrow(loan, tokenId, ceiling);

        return (loan, tokenId, ceiling);
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
        invest(amount);
        hevm.warp(now + 1 days);
        coordinator.closeEpoch();
        emit log_named_uint("reserve", reserve.totalBalance());
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

    function defaultCollateral() public pure returns(uint nftPrice, uint riskGroup) {
        uint nftPrice = 100 ether;
        uint riskGroup = 2;
        return (nftPrice, riskGroup);
    }

    // note: this method will be refactored with the new lender side contracts, as the distributor should not hold any currency
    function currdistributorBal() public view returns(uint) {
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
        uint distributorShould = pile.debt(loan) + currdistributorBal();
        // close without defined amount
        borrower.doClose(loan);
        uint totalT = uint(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, distributorShould);
    }

    uint TWO_DECIMAL_PRECISION = 10**16;
    uint FIXED27_TWO_DECIMAL_PRECISION = 10**25;

    function assertEq(uint a, uint b, uint precision)  public {
        assertEq(a/precision, b/precision);
    }

    function fixed18To27(uint valPower18) public returns(uint) {
        // convert 10^18 to 10^27
        return valPower18 * 10**9;
    }

    function setupRepayReq() public returns(uint) {
        // borrower needs some currency to pay rate
        uint extra = 100000000000 ether;
        currency.mint(borrower_, extra);

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), uint(-1));

        return extra;
    }

}
