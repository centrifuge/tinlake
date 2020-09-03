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

    function baseSetup() public {
        // setup deployment
        bytes32 feed_ = "default";
        deployContracts(feed_);
    }

    function baseSetup(bytes32 feed_) public {
        deployContracts(feed_);
    }

    function createTestUsers(bool senior_) public {
        borrower = new Borrower(address(shelf), address(lenderDeployer.distributor()), currency_, address(pile));
        borrower_ = address(borrower);

        randomUser = new Borrower(address(shelf), address(distributor), currency_, address(pile));
        randomUser_ = address(randomUser);

        keeper = new Keeper(address(collector), currency_);
        keeper_ = address(keeper);

        admin = new AdminUser(address(shelf), address(pile), address(nftFeed), address(title), address(distributor), address(collector));
        admin_ = address(admin);
        root.relyBorrowAdmin(admin_);

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
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        admin.priceNFTAndSetRiskGroup(lookupId, nftPrice, riskGroup);
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
        currency.mint(address(distributor), currencyAmount);
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
}
