// Copyright (C) 2020 Centrifuge
//
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
//
pragma solidity >=0.5.15 <0.6.0;

import "../base_system.sol";

contract CollectTest is BaseSystemTest {

    Hevm public hevm;

    function setUp() public {
        baseSetup();
        createTestUsers();

        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(1234567);
        fundTranches();
    }

    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        invest(defaultAmount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
    }

    function collect(uint loanId, uint tokenId, bool whitelisted) public {
        ( , uint recoveryAmount ) = collector.options(loanId);
        uint initialKeeperBalance = currency.balanceOf(keeper_);
        uint initialJuniorBalance = currency.balanceOf(address(lenderDeployer.reserve()));
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
        assert(pile.debt(loanId) >= nftFeed.threshold(loanId));
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
        assertEq(currency.balanceOf(address(lenderDeployer.reserve())), safeAdd(initialJuniorBalance, recoveryAmount));
        // assert: loan balance = 0
        assertEq(shelf.balances(loanId), 0);
        // assert: total balance got decreased by initial loanBalance
        assertEq(shelf.balance(), safeSub(initialTotalBalance, initialLoanBalance));
    }

    function setupCollect(uint loanId, uint recoveryPrice, address usr, bool isWhitelisted,
        bool isAssigned, bool doTopup, bool doApprove) public {
       
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
        // threshold has to be reached after 1 year
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  

        bool assigned = true;
        bool whitelisted = false;
        bool doTopup  = true;
        bool doApprove = true;
       
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        // after 10 days debt higher than threshold 168 ether
        hevm.warp(now + 10 days); // -> 100 * ((1.05)^10) ~ loanSize 162.88 ether
       
        uint recoveryPrice = pile.debt(loanId);
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
    
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testCollectWhitelistedKeeper() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  
        bool assigned = false;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        // after 10 days debt higher than threshold 168 ether
        hevm.warp(now + 10 days);
        uint recoveryPrice = pile.debt(loanId);
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
    
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, whitelisted);
    }

    function testCollectPriceSmallerDebt() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  
        bool assigned = true;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;

        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = safeDiv(pile.debt(loanId), 2);
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
       
        // after 10 days debt higher than threshold 168 ether
        hevm.warp(now + 10 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testCollectPriceHigherDebt() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  

        bool assigned = true;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;

        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        // after 10 days debt higher than threshold 168 ether
        hevm.warp(now + 10 days);
        // price twice as high as debt
        uint recoveryPrice = safeMul(pile.debt(loanId), 2);

        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testCollectAndIssueLoan() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  
        
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = pile.debt(loanId);
    
        hevm.warp(now + 10 days);
  
        // borrower is added as keeper and collects loan
        addKeeperAndCollect(loanId, borrower_, recoveryPrice);
        // borrower closes old loan, to create a new one (randomUser is still loanOwner)
        borrower.close(loanId);
        // borrower creates new loan
        borrower.issue(collateralNFT_, tokenId);
    }

    function testFailCollectAndIssueNotClosed() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = pile.debt(loanId);

        // after 10 days debt higher than threshold 168 ether
        hevm.warp(now + 10 days);
        // borrower is added as keeper and collects loan
        addKeeperAndCollect(loanId, borrower_, recoveryPrice);

        // borrower does not close old loan
        // should fail: borrower creates new loan
        borrower.issue(collateralNFT_, tokenId);
    }

    function testFailCollectNotWhitelisted() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  
        bool assigned = false;
        bool whitelisted = false;
        bool doTopup  = true;
        bool doApprove = true;
        
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = pile.debt(loanId);
        
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 10 days debt higher than threshold 168 ether
        hevm.warp(now + 10 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testFailCollectLoanHasAssignedKeeper() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  
        bool assigned = false;
        bool whitelisted = true;
        bool doTopup  = true;
        bool doApprove = true;
       
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = pile.debt(loanId);
        
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // assign random keeper to loan
        admin.addKeeper(loanId, randomUser_, recoveryPrice);
        // after 10 days debt higher than threshold 168 ether
        hevm.warp(now + 10 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, true);
    }

    function testFailCollectNotSeized() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether  
        
        bool assigned = true;
        bool whitelisted = false;
        bool doTopup  = true;
        bool doApprove = true;

        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = pile.debt(loanId);
    
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 1 year debt has not reached threshold
        hevm.warp(now + 10 days);
        // seize loan
        // collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testFailCollectKeeperNotEnoughFunds() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether 

        bool assigned = true;
        bool whitelisted = false;
        // do not topup keeper
        bool doTopup  = false;
        bool doApprove = true;

        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = pile.debt(loanId);
    
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);

        // after 1 year threshold reached
        hevm.warp(now + 10 days);
        // seize loan
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

    function testFailCollectNoApproval() public {
        uint riskGroup = 4; // interest: 5 % per day, ceiling: 50 %, threshold 60 %
        uint nftPrice = 200 ether; // ceiling 100 ether, threshold: 120 ether 
        bool assigned = true;
        bool whitelisted = false;
        bool doTopup  = true;
        // keeper does not approve shelf to take funds
        bool doApprove = false;

        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        uint recoveryPrice = pile.debt(loanId);
        setupCollect(loanId, recoveryPrice, keeper_, whitelisted, assigned, doTopup, doApprove);
        
        hevm.warp(now + 10 days);
        collector.seize(loanId);
        assertPreCondition(loanId, tokenId);
        collect(loanId, tokenId, false);
    }

 }
