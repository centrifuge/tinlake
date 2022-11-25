// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.0;

import "../../lib/tinlake-title/src/title.sol";
import "forge-std/Test.sol";
import {Assertions} from "./assertions.sol";

import {TinlakeRoot} from "src/root.sol";
import {BorrowerDeployer} from "src/borrower/deployer.sol";
import {AdapterDeployer} from "src/lender/adapters/deployer.sol";
import {LenderDeployer} from "src/lender/deployer.sol";
import {Reserve} from "src/lender/reserve.sol";
import {Clerk} from "src/lender/adapters/mkr/clerk.sol";
import {PoolAdmin} from "src/lender/admin/pool.sol";
import {Assessor} from "src/lender/assessor.sol";
import {Operator} from "src/lender/operator.sol";
import {Tranche} from "src/lender/tranche.sol";
import {EpochCoordinator} from "src/lender/coordinator.sol";
import {Pile} from "src/borrower/pile.sol";
import {Shelf} from "src/borrower/shelf.sol";
import {NAVFeedPV} from "src/borrower/feed/navfeedPV.sol";

interface T_ERC20 {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
    function mint(address, uint256) external;
    function burn(address, uint256) external;
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external;
    function ceiling(uint256 loan) external view returns (uint256);
}

interface TAuth {
    function rely(address) external;
    function deny(address) external;
    function wards(address) external returns (uint256);
}

interface MgrLike {
    function urn() external returns (address);
}

contract TinlakeRPCTests is Test, Assertions {
    TinlakeRoot root;
    PoolAdmin poolAdmin;
    Assessor assessor;
    Operator juniorOperator;
    Operator seniorOperator;
    EpochCoordinator coordinator;
    NAVFeedPV navFeed;
    Shelf shelf;
    Pile pile;
    Reserve reserve;
    Clerk clerk;
    Title registry;
    T_ERC20 currency;
    T_ERC20 juniorToken;
    T_ERC20 seniorToken;
    Tranche seniorTranche;
    Tranche juniorTranche;
    MgrLike mgr;

    function initRPC(address _root) public {
        root = TinlakeRoot(_root);
        BorrowerDeployer borrowerDeployer = BorrowerDeployer(address(root.borrowerDeployer()));
        LenderDeployer lenderDeployer = LenderDeployer(address(root.lenderDeployer()));
        AdapterDeployer adapterDeployer = AdapterDeployer(address(root.adapterDeployer()));

        poolAdmin = PoolAdmin(address(lenderDeployer.poolAdmin()));
        navFeed = NAVFeedPV(address(borrowerDeployer.feed()));
        shelf = Shelf(address(borrowerDeployer.shelf()));
        pile = Pile(address(borrowerDeployer.pile()));
        assessor = Assessor(address(lenderDeployer.assessor()));
        seniorOperator = Operator(address(lenderDeployer.seniorOperator()));
        juniorOperator = Operator(address(lenderDeployer.juniorOperator()));
        seniorTranche = Tranche(address(lenderDeployer.seniorTranche()));
        juniorTranche = Tranche(address(lenderDeployer.juniorTranche()));
        coordinator = EpochCoordinator(address(lenderDeployer.coordinator()));
        reserve = Reserve(address(lenderDeployer.reserve()));
        clerk = Clerk(address(adapterDeployer.clerk()));
        juniorToken = T_ERC20(address(lenderDeployer.juniorToken()));
        seniorToken = T_ERC20(address(lenderDeployer.seniorToken()));
        currency = T_ERC20(address(Reserve(address(lenderDeployer.reserve())).currency()));
        registry = new Title("TEST", "TEST");
        mgr = MgrLike(address(clerk.mgr()));

        // cheat: give testContract permissions on root contract by overriding storage
        // storage slot for permissions => keccak256(key, mapslot) (mapslot = 0)
        vm.store(address(root), keccak256(abi.encode(address(this), uint256(0))), bytes32(uint256(1)));
        vm.warp(block.timestamp + 2 days);

        vm.startPrank(address(root));
        navFeed.file(
            "riskGroup",
            0, // riskGroup:       0
            8 * 10 ** 26, // thresholdRatio   70%
            6 * 10 ** 26, // ceilingRatio     60%
            uint256(1000000564701133626865910626) // interestRate     5% per year
        );
        vm.stopPrank();
    }

    function disburse(uint256 preMakerDebt, uint256, uint256 seniorInvest, uint256 juniorInvest, bool withMaker)
        public
    {
        // close epoch & disburse
        vm.warp(block.timestamp + coordinator.challengeTime());

        uint256 lastEpochExecuted = coordinator.lastEpochExecuted();

        seniorOperator.disburse();
        juniorOperator.disburse();

        (, uint256 seniorSupplyFulfill, uint256 seniorPrice) = seniorTranche.epochs(lastEpochExecuted);
        (, uint256 juniorSupplyFulfill, uint256 juniorPrice) = juniorTranche.epochs(lastEpochExecuted);

        // effective invested in this epoch
        juniorInvest = rmul(juniorInvest, juniorSupplyFulfill);
        seniorInvest = rmul(seniorInvest, seniorSupplyFulfill);

        uint256 juniorTokenExpected = rdiv(juniorInvest, juniorPrice);
        uint256 seniorTokenExpected = rdiv(seniorInvest, seniorPrice);

        // check correct juniorToken & drop token received
        assertEqTol(juniorToken.balanceOf(address(this)), juniorTokenExpected, "rpc#1");
        assertEqTol(seniorToken.balanceOf(address(this)), seniorTokenExpected, "rpc#2");

        uint256 investAmount = safeAdd(seniorInvest, juniorInvest);

        if (withMaker) {
            uint256 wipeAmount = assertMakerDebtReduced(preMakerDebt, investAmount);
            assertEqTol(preMakerDebt - wipeAmount, clerk.debt(), "rpc#3");
            // check maker debt reduced correctly
        }
    }

    function investTranches(bool withMaker) public {
        // pre invest state
        uint256 preReserveDaiBalance = currency.balanceOf(address(reserve));

        uint256 preMakerDebt = 0;
        if (withMaker) preMakerDebt = clerk.debt();

        // get admin super powers
        root.relyContract(address(poolAdmin), address(this));
        // whitelist self for juniorToken & seniorToken
        poolAdmin.setAdminLevel(address(this), 1);
        poolAdmin.updateSeniorMember(address(this), uint256(-1));
        poolAdmin.updateJuniorMember(address(this), uint256(-1));

        // get super powers on DAI contract
        vm.store(address(currency), keccak256(abi.encode(address(this), uint256(0))), bytes32(uint256(1)));

        // mint DAI
        uint256 maxInvest = (assessor.maxReserve() - assessor.totalBalance()) / 2;
        // make sure investment amount does not brek max reserve
        currency.mint(address(this), maxInvest);

        uint256 seniorInvest = maxInvest / 2;
        // in Maker pools the minSeniorRatio is zero => more TIN always welcome
        uint256 juniorInvest = maxInvest - seniorInvest;
        // uint seniorInvest = 1 ether;
        // uint juniorInvest = 1 ether;

        // invest tranches
        currency.approve(address(seniorTranche), type(uint256).max);
        // invest senior
        seniorOperator.supplyOrder(seniorInvest);

        currency.approve(address(juniorTranche), type(uint256).max);
        // invest junior
        juniorOperator.supplyOrder(juniorInvest);

        coordinator.closeEpoch();

        // todo handle submission period case
        assertTrue(coordinator.submissionPeriod() == false);

        disburse(preMakerDebt, preReserveDaiBalance, seniorInvest, juniorInvest, withMaker);
    }

    function appraiseNFT(uint256 tokenId, uint256 nftPrice, uint256 maturityDate) public {
        root.relyContract(address(navFeed), address(this));
        bytes32 nftId = keccak256(abi.encodePacked(address(registry), tokenId));
        navFeed.update(nftId, nftPrice, 0);

        // TODO: enable below line if nav feed != PV
        // navFeed.file("maturityDate", nftId, maturityDate);
    }

    function raiseCreditLine(uint256 raiseAmount) public {
        uint256 preCreditline = clerk.creditline();
        root.relyContract(address(clerk), address(this));
        clerk.raise(raiseAmount);
        assertEq(clerk.creditline(), safeAdd(preCreditline, raiseAmount));
    }

    function borrowLoan(uint256 loanId, uint256 borrowAmount) public {
        uint256 preDaiBalance = currency.balanceOf(address(this));
        // borrow
        shelf.borrow(loanId, borrowAmount);
        // withdraw
        shelf.withdraw(loanId, borrowAmount, address(this));
        // assert currency received
        assertEq(currency.balanceOf(address(this)), preDaiBalance + borrowAmount);
    }

    function repayLoan(uint256 loanId, uint256 repayAmount) public {
        currency.mint(address(this), repayAmount);
        currency.approve(address(shelf), uint256(-1));
        uint256 preDaiBalance = currency.balanceOf(address(this));
        // repay debt
        shelf.repay(loanId, repayAmount);
        // assert currency paid
        assertEq(currency.balanceOf(address(this)), preDaiBalance - repayAmount);
    }

    function runLoanCycleWithMaker() public {
        vm.startPrank(address(root));
        assessor.rely(address(this));
        vm.stopPrank();
        assessor.file("maxReserve", 1000000000000 * 1 ether);

        investTranches(true);

        // issue nft
        uint256 tokenId = registry.issue(address(this));
        // issue loan
        uint256 loanId = shelf.issue(address(registry), tokenId);

        // raise creditline
        uint256 raiseAmount = 100 ether;
        raiseCreditLine(raiseAmount);

        // appraise nft
        uint256 totalAvailable = assessor.totalBalance();
        uint256 nftPrice = totalAvailable * 2;
        uint256 maturityDate = block.timestamp + 2 weeks;
        appraiseNFT(tokenId, nftPrice, maturityDate);

        // lock asset nft
        registry.setApprovalForAll(address(shelf), true);
        shelf.lock(loanId);

        // borrow loan with half of the creditline
        uint256 borrowAmount = reserve.totalBalance() + clerk.creditline() / 2;
        uint256 preMakerDebt = clerk.debt();
        assertEq(navFeed.currentNAV(), 0);

        borrowLoan(loanId, borrowAmount);
        assertEq(navFeed.currentNAV(), 50 ether);

        // check debt increase in maker
        assertEqTol(clerk.debt(), preMakerDebt + (clerk.creditline() / 2), "clerk debt");

        // jump 5 days into the future
        vm.warp(block.timestamp + 5 days);

        // repay entire loan debt
        uint256 debt = pile.debt(loanId);
        // repayment should reduce maker debt
        preMakerDebt = clerk.debt();
        repayLoan(loanId, debt);
        assertTrue(clerk.debt() < preMakerDebt);
        assertEq(navFeed.currentNAV(), 0);
    }

    function runLoanCycleWithoutMaker() public {
        vm.startPrank(address(root));
        assessor.rely(address(this));
        vm.stopPrank();
        assessor.file("maxReserve", 1000000000000 * 1 ether);

        investTranches(false);

        // issue nft
        uint256 tokenId = registry.issue(address(this));
        // issue loan
        uint256 loanId = shelf.issue(address(registry), tokenId);

        // appraise nft
        uint256 totalAvailable = assessor.totalBalance();
        uint256 nftPrice = totalAvailable * 2;
        uint256 maturityDate = block.timestamp + 2 weeks;
        appraiseNFT(tokenId, nftPrice, maturityDate);

        // lock asset nft
        registry.setApprovalForAll(address(shelf), true);
        shelf.lock(loanId);

        // borrow loan with half of the creditline
        uint256 borrowAmount = reserve.totalBalance();

        borrowLoan(loanId, borrowAmount);

        // jump 5 days into the future
        vm.warp(block.timestamp + 5 days);

        // repay entire loan debt
        uint256 debt = pile.debt(loanId);
        repayLoan(loanId, debt);
    }

    // helper
    function assertHasPermissions(address con, address ward) public {
        uint256 perm = TAuth(con).wards(ward);
        assertEq(perm, 1);
    }

    function assertHasNoPermissions(address con, address ward) public {
        uint256 perm = TAuth(con).wards(ward);
        assertEq(perm, 0);
    }

    function assertMakerDebtReduced(uint256 preDebt, uint256 investmentAmount) public returns (uint256 wipeAmount) {
        if (preDebt > 1) {
            if (preDebt > investmentAmount) {
                assertEq(clerk.debt(), (preDebt - investmentAmount));
                return investmentAmount;
            } else {
                assertTrue(clerk.debt() <= 1);
                return preDebt;
            }
        }
        return 0;
    }
}
