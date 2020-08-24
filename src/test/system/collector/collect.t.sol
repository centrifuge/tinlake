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

import "../base_system.sol";

contract CollectTest is BaseSystemTest {

    Hevm public hevm;

    function setUp() public {
        baseSetup();
        createTestUsers(false);

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);

        fundTranches();
    }

    function collect(uint loanId, uint tokenId, bool whitelisted) public {
        ( , uint recoveryAmount ) = collector.options(loanId);
        uint initialKeeperBalance = currency.balanceOf(keeper_);
        uint initialJuniorBalance = currency.balanceOf(address(lenderDeployer.distributor()));
        uint initialTotalBalance = shelf.balance();
        uint initialLoanBalance = shelf.balances(loanId);
        if (whitelisted) {
            keeper.collect(loanId);
        } else {
            admin.collect(loanId, keeper_);
        }
        assertPostCondition(loanId, tokenId, recoveryAmount, initialKeeperBalance, initialJuniorBalance, initialTotalBalance, initialLoanBalance);
    }

    function assertPreCondition(uint loanId, uint tokenId) public {
        // assert: loan can be seized
        assertEq(collateralNFT.ownerOf(tokenId), address(collector));
        // assert: debt > threshold
        assert(pile.debt(loanId) >= threshold.get(loanId));
        (address assigned, uint price ) = collector.options(loanId);
        // assert: keeper is whitelisted
        assert(assigned == keeper_ || collector.collectors(keeper_) == 1);
        // assert: loan has a recovery price attached
        assert(price > 0);
        // assert: keeper has enough funds
        assert(currency.balanceOf(keeper_) >= price);
    }

    function assertPostCondition(uint loanId, uint tokenId, uint recoveryAmount, uint initialKeeperBalance, uint initialJuniorBalance, uint initialTotalBalance, uint initialLoanBalance) public {
        // assert: nft got transferred to keeper
        assertEq(collateralNFT.ownerOf(tokenId), address(keeper));
        // assert: loanDebt set to 0 indipendant of recovery value
        assertEq(pile.debt(loanId), 0);
        // assert: keeper transferred funds
        assertEq(currency.balanceOf(keeper_), safeSub(initialKeeperBalance, recoveryAmount));
        // assert: shelf received recoveryAmount
        assertEq(currency.balanceOf(address(lenderDeployer.distributor())), safeAdd(initialJuniorBalance, recoveryAmount));
        // assert: loan balance = 0
        assertEq(shelf.balances(loanId), 0);
        // assert: total balance got decreased by initial loanBalance
        assertEq(shelf.balance(), safeSub(initialTotalBalance, initialLoanBalance));
    }

    function setupCollect(uint loanId, uint threshold, uint recoveryPrice, address usr, bool isWhitelisted,
        bool isAssigned, bool doTopup, bool doApprove) public {
        // set loan threshold
        admin.setThreshold(loanId, threshold);
        // keeper assigned to a certain loan. Loan can just be collected by this keeper
        if (isAssigned) { admin.addKeeper(loanId, keeper_, recoveryPrice); }
        // keeper whitelisted to call collect and collect all loans that are not assigned
        if (isWhitelisted) {
            // just set the price, do not assign keeper to the loan
            admin.setCollectPrice(loanId, recoveryPrice);
            // add keeper to whitelist
            admin.whitelistKeeper(usr);
        }
        // topup keeper
        if (doTopup) { topUp(keeper_); }
        // keeper approves shelf to take currency
        if (doApprove) { keeper.approveCurrency(address(shelf), uint(-1)); }
    }

    function testCollectAssignedKeeper() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint recoveryPrice = 73.92 ether; // expected debt after 1 year
        bool assigned = true;
        bool whitelisted = false;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testCollectWhitelistedKeeper() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint recoveryPrice = 73.92 ether; // expected debt after 1 year
        bool assigned = false;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, whitelisted);
    }

    function testCollectPriceSmallerDebt() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint recoveryPrice = safeDiv(ceiling, 2); // recoveryPrice half loan initial debt
        bool assigned = true;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testCollectPriceHigherDebt() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint expectedDebt = 73.92 ether; // expected debt after 1 year
        uint recoveryPrice = safeMul(expectedDebt, 2); // recoveryPrice double loan debt after 1 year
        bool assigned = true;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testCollectAndIssueLoan() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(randomUser_, ceiling, rate, speed);
        uint threshold = 70 ether;
        uint recoveryPrice = ceiling;
        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // borrower is added as keeper and collects loan
        addKeeperAndCollect(loanId, threshold, borrower_, recoveryPrice);
        // borrower closes old loan, to create a new one (randomUser is still loanOwner)
        borrower.close(loanId);
        // borrower creates new loan
        borrower.issue(collateralNFT_, tokenId);
    }

    function testFailCollectAndIssueNotClosed() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(randomUser_, ceiling, rate, speed);
        uint threshold = 70 ether;
        uint recoveryPrice = ceiling;
        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // borrower is added as keeper and collects loan
        addKeeperAndCollect(loanId, threshold, borrower_, recoveryPrice);

        // borrower does not close old loan

        // should fail: borrower creates new loan
        borrower.issue(collateralNFT_, tokenId);
    }

    function testFailCollectNotWhitelisted() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint recoveryPrice = 73.92 ether; // expected debt after 1 year
        bool assigned = false;
        bool whitelisted = false;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testFailCollectLoanHasAssignedKeeper() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint recoveryPrice = 73.92 ether; // expected debt after 1 year
        bool assigned = false;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
        // assign random keeper to loan
        admin.addKeeper(loanId, randomUser_, recoveryPrice);
        // after 1 year debt higher than threshold
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, true);
    }

    function testFailCollectNotSeized() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 300 ether;
        uint recoveryPrice = 73.92 ether; // expected debt after 1 year
        bool assigned = true;
        bool whitelisted = false;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 1 year debt has not reached threshold
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testFailCollectKeeperNotEnoughFunds() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint recoveryPrice = 73.92 ether; // expected debt after 1 year
        bool assigned = true;
        bool whitelisted = false;
        // do not topup keeper
        bool doTopup  = false;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
        // after 1 year threshold reached
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testFailCollectNoApproval() public {
        uint ceiling = 66 ether;
        uint rate = 1000000003593629043335673583; // 12 % per year compound in seconds
        uint speed = rate;
        uint threshold = 70 ether;
        uint recoveryPrice = 73.92 ether; // expected debt after 1 year
        bool assigned = true;
        bool whitelisted = false;
        bool doTopup  = true;
        // keeper does not approve shelf to take funds
        bool doApprove = false;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, ceiling, rate, speed);
        setupCollect(loanId, threshold, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
        // after 1 year threshold reached
        hevm.warp(now + 365 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

}
