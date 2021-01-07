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
pragma experimental ABIEncoderV2;

import "../../test_suite.sol";
import "tinlake-math/interest.sol";
import {BaseTypes} from "../../../../lender/test/coordinator-base.t.sol";
import { MKRAssessor }from "../../../../lender/adapters/mkr/assessor.sol";


contract LenderSystemTest is TestSuite, Interest {
    MKRAssessor mkrAssessor;

    function setUp() public {
        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        bool mkrAdapter = true;
        TinlakeConfig memory defaultConfig = defaultConfig();
        deployContracts(mkrAdapter, defaultConfig);
        createTestUsers();

        nftFeed_ = NFTFeedLike(address(nftFeed));

        root.relyContract(address(clerk), address(this));
        mkrAssessor = MKRAssessor(address(assessor));
        mkr.depend("currency" ,currency_);
        mkr.depend("drop", mkrLenderDeployer.seniorToken());
    }

    // setup a running pool with default values
    function _setupRunningPool() internal {
        uint seniorSupplyAmount = 1500 ether;
        uint juniorSupplyAmount = 200 ether;
        uint nftPrice = 200 ether;
        // interest rate default => 5% per day
        uint borrowAmount = 100 ether;
        uint maturityDate = 5 days;

        ModelInput memory submission = ModelInput({
            seniorSupply : 800 ether,
            juniorSupply : 200 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        supplyAndBorrowFirstLoan(seniorSupplyAmount, juniorSupplyAmount, nftPrice, borrowAmount, maturityDate, submission);
    }

    function testMKRRaise() public {
        _setupRunningPool();
        uint preReserve = assessor.totalBalance();
        uint nav = nftFeed.calcUpdateNAV();
        uint preSeniorBalance = assessor.seniorBalance();

        uint amountDAI = 10 ether;

        clerk.raise(amountDAI);

        //raise reserves a spot for drop and locks the tin
        assertEq(assessor.seniorBalance(), safeAdd(preSeniorBalance, rmul(amountDAI, clerk.mat())));
        assertEq(assessor.totalBalance(), safeAdd(preReserve, amountDAI));

        assertEq(mkrAssessor.effectiveTotalBalance(), preReserve);
        assertEq(mkrAssessor.effectiveSeniorBalance(), preSeniorBalance);
        assertEq(clerk.remainingCredit(), amountDAI);
    }

    function testMKRDraw() public {
        _setupRunningPool();
        uint preReserve = assessor.totalBalance();
        uint nav = nftFeed.calcUpdateNAV();
        uint preSeniorBalance = assessor.seniorBalance();

        uint creditLineAmount = 10 ether;
        uint drawAmount = 5 ether;
        clerk.raise(creditLineAmount);

        //raise reserves a spot for drop and locks the tin
        assertEq(assessor.seniorBalance(), safeAdd(preSeniorBalance, rmul(creditLineAmount, clerk.mat())));
        assertEq(assessor.totalBalance(), safeAdd(preReserve, creditLineAmount));

        uint preSeniorDebt = assessor.seniorDebt();
        clerk.draw(drawAmount);

        // seniorBalance and reserve should have changed
        assertEq(mkrAssessor.effectiveTotalBalance(), safeAdd(preReserve, drawAmount));

        assertEq(safeAdd(mkrAssessor.effectiveSeniorBalance(),assessor.seniorDebt()),
            safeAdd(safeAdd(preSeniorBalance, rmul(drawAmount, clerk.mat())), preSeniorDebt));

        //raise reserves a spot for drop and locks the tin. no impact from the draw function
        assertEq(safeAdd(assessor.seniorBalance(),assessor.seniorDebt()),
            safeAdd(safeAdd(preSeniorBalance, rmul(creditLineAmount, clerk.mat())), preSeniorDebt));

        assertEq(assessor.totalBalance(), safeAdd(preReserve, creditLineAmount));
    }


    function _setUpMKRLine(uint juniorAmount, uint mkrAmount) internal {
        root.relyContract(address(reserve), address(this));

        root.relyContract(address(mkrAssessor), address(this));
        mkrAssessor.file("minSeniorRatio", 0);

        // activate clerk in reserve
        reserve.depend("lending", address(clerk));

        uint juniorSupplyAmount = 200 ether;
        juniorSupply(juniorSupplyAmount);

        hevm.warp(now + 1 days);

        bool closeWithExecute = true;
        closeEpoch(true);
        assertTrue(coordinator.submissionPeriod() == false);

        uint creditLineAmount = 500 ether;
        clerk.raise(creditLineAmount);

        assertEq(clerk.remainingCredit(), creditLineAmount);
    }

    function _setUpDraw(uint mkrAmount, uint juniorAmount, uint borrowAmount) public {
        _setUpMKRLine(juniorAmount, mkrAmount);
        setupOngoingDefaultLoan(borrowAmount);
        assertEq(currency.balanceOf(address(borrower)), borrowAmount, " _setUpDraw#1");
        uint debt = 0;
        if(borrowAmount > juniorAmount) {
            debt = safeSub(borrowAmount, juniorAmount);
        }
        assertEq(clerk.debt(), debt);
    }

    function testOnDemandDraw() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
    }

    function testOnDemandDrawWithStabilityFee() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(now + 1 days);
        assertEq(clerk.debt(), 105 ether, "testStabilityFee#2");
    }

    function testTotalBalanceBuffer() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(now + 1 days);

        uint debt = clerk.debt();
        uint buffer = safeSub(rmul(rpow(clerk.stabilityFee(),
                safeSub(safeAdd(block.timestamp, mkrAssessor.creditBufferTime()), block.timestamp), ONE), debt), debt);

        uint remainingCredit = clerk.remainingCredit();
        assertEq(assessor.totalBalance(), safeSub(remainingCredit, buffer));
    }

    function testLoanRepayWipe() public {
        uint fee = 1000000564701133626865910626; // 5% per day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(now + 1 days);
        uint expectedDebt = 105 ether;
        assertEq(clerk.debt(), expectedDebt, "testLoanRepayWipe#1");

        uint repayAmount = 50 ether;
        repayDefaultLoan(repayAmount);

        // reduces clerk debt
        assertEq(clerk.debt(), expectedDebt-repayAmount, "testLoanRepayWipe#2");
        assertEq(reserve.totalBalance(), 0, "testLoanRepayWipe#3");
    }

    function testMKRHarvest() public {
        uint fee = uint(1000000115165872987700711356);    // 1 % day
        mkr.file("stabilityFee", fee);
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);
        hevm.warp(now + 1 days);
        uint expectedDebt = 101 ether;
        assertEqTol(clerk.debt(), expectedDebt, "testMKRHarvest#1");

        hevm.warp(now + 3 days);

        uint seniorPrice = mkrAssessor.calcSeniorTokenPrice();
        uint juniorPrice = mkrAssessor.calcJuniorTokenPrice();

        uint lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer
        uint profitDAI = safeSub(lockedCollateralDAI, clerk.calcOvercollAmount(clerk.debt()));
        uint preSeniorAsset = safeAdd(assessor.seniorDebt(), assessor.seniorBalance_());

        uint preJuniorStake = clerk.juniorStake();

        clerk.harvest();

        uint newJuniorPrice = mkrAssessor.calcJuniorTokenPrice();
        uint newSeniorPrice =  mkrAssessor.calcSeniorTokenPrice();

        assertEq(newJuniorPrice, juniorPrice);
        assertEq(preJuniorStake, safeAdd(clerk.juniorStake(), profitDAI));
        assertEq(safeSub(preSeniorAsset,profitDAI), safeAdd(assessor.seniorDebt(), assessor.seniorBalance_()));
    }

    function testMKRHeal() public {
        // high stability fee: 10% a day
        uint fee = uint(1000001103127689513476993126);
        mkr.file("stabilityFee", fee);

        // sanity check
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        hevm.warp(now + 1 days);
        uint expectedDebt = 110 ether;

        uint seniorPrice = mkrAssessor.calcSeniorTokenPrice();
        uint lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        assertEqTol(clerk.debt(), expectedDebt, "testMKRHeal#1");

        uint wantedLocked = clerk.calcOvercollAmount(clerk.debt());
        assertTrue(wantedLocked > lockedCollateralDAI);

        uint amountOfDROP = clerk.cdpink();

        clerk.heal();
        // heal should have minted additional DROP tokens
        lockedCollateralDAI = rmul(clerk.cdpink(), seniorPrice);
        assertEqTol(lockedCollateralDAI, wantedLocked, "testMKRHeal#2");
        assertTrue(clerk.cdpink() > amountOfDROP);

    }

    function testMKRSink() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        uint sinkAmount = 50 ether;
        uint totalBalance = mkrAssessor.totalBalance();
        uint seniorBalance = mkrAssessor.seniorBalance();

        clerk.sink(sinkAmount);
        assertEq(mkrAssessor.totalBalance()+sinkAmount, totalBalance);
        assertEq(mkrAssessor.seniorBalance()+rmul(sinkAmount, clerk.mat()), seniorBalance);
    }

    function testFailMKRSinkTooHigh() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        uint sinkAmount = 401 ether;
        clerk.sink(sinkAmount);
    }

    function testMKRSinkAfterRaise() public {
        uint mkrAmount = 500 ether;
        uint juniorAmount = 200 ether;
        _setUpMKRLine(juniorAmount, mkrAmount);
       clerk.sink(mkrAmount);
    }

    function testVaultLiquidation() public {
        uint juniorAmount = 200 ether;
        uint mkrAmount = 500 ether;
        uint borrowAmount = 300 ether;
        _setUpDraw(mkrAmount, juniorAmount, borrowAmount);

        uint juniorTokenPrice = mkrAssessor.calcJuniorTokenPrice();

        // liquidation
        mkr.file("live", false);

        assertTrue(mkrAssessor.calcJuniorTokenPrice() <  juniorTokenPrice);
        // no currency in reserve
        assertEq(reserve.totalBalance(),  0);

        // repay loans and everybody redeems
        repayAllDebtDefaultLoan();
        assertEq(mkrAssessor.currentNAV(), 0);
        // reserve should keep the currency no automatic clerk.wipe
        assertTrue(reserve.totalBalance() > 0);

        //sanity check - correct currency amount for each token

        uint seniorTokenInMK = clerk.cdpink();
        uint seniorTokenSeniorInvestor = seniorToken.balanceOf(address(seniorInvestor));
        uint unRedeemedSeniorToken = seniorToken.balanceOf(address(seniorTranche));
        uint juniorInvestorToken = juniorToken.balanceOf(address(juniorInvestor));

        assertEq(reserve.totalBalance(), rmul(seniorTokenInMK + seniorTokenSeniorInvestor + unRedeemedSeniorToken, assessor.calcSeniorTokenPrice())
            + rmul(juniorInvestorToken, assessor.calcJuniorTokenPrice()));
    }

}
