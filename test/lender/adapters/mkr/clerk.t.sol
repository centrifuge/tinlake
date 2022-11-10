// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/interest.sol";

import "src/lender/adapters/mkr/clerk.sol";
import "src/lender/adapters/mkr/simpleClerk.sol";
import "../../../simple/token.sol";
import "../../mock/reserve.sol";
import "../../mock/coordinator.sol";
import "../../mock/navFeed.sol";
import "../../mock/assessor.sol";
import "../../mock/tranche.sol";
import "./mock/mgr.sol";
import "./mock/spotter.sol";
import "./mock/vat.sol";
import "./mock/jug.sol";
import "src/lender/definitions.sol";
import "../../../system/assertions.sol";

interface Hevm {
    function warp(uint256) external;
}

contract AssessorMockWithDef is AssessorMock, Definitions {}

contract ClerkTest is Assertions, Interest {
    Hevm hevm;

    SimpleToken currency;
    SimpleToken collateral;
    ReserveMock reserve;
    AssessorMockWithDef assessor;
    CoordinatorMock coordinator;
    TrancheMock tranche;

    ManagerMock mgr;
    VatMock vat;
    SpotterMock spotter;
    JugMock jug;

    SimpleClerk clerk;
    address self;

    function setUp() public {
        currency = new SimpleToken("DAI", "DAI");
        collateral = new SimpleToken("DROP", "DROP");

        reserve = new ReserveMock(address(currency));
        assessor = new AssessorMockWithDef();
        coordinator = new CoordinatorMock();
        tranche = new TrancheMock();
        mgr = new ManagerMock(address(currency), address(collateral));
        mgr.setIlk("DROP");
        vat = new VatMock();
        spotter = new SpotterMock();
        jug = new JugMock();

        clerk = new SimpleClerk(address(currency), address(collateral));
        clerk.depend("coordinator", address(coordinator));
        clerk.depend("assessor", address(assessor));
        clerk.depend("reserve", address(reserve));
        clerk.depend("tranche", address(tranche));
        clerk.depend("mgr", address(mgr));
        clerk.depend("spotter", address(spotter));
        clerk.depend("vat", address(vat));
        clerk.depend("jug", address(jug));

        tranche.depend("token", address(collateral));
        tranche.rely(address(clerk));

        self = address(this);

        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(block.timestamp);

        // set values for the MKR contracts
        // mat = 110% -> 10% extra security margin required for mkr
        uint256 mat = 1.1 * 10 ** 27;
        spotter.setReturn("mat", mat);
        spotter.setReturn("pip", address(0));
        // set stability fee to 0
        vat.setReturn("stabilityFeeIdx", ONE);
        mgr.setVat(address(vat));
        mgr.setBytes32Return("ilk", "DROP");
        // cdp not in soft liquidation
        mgr.setReturn("safe", true);
        // cdp not in hard liquidation
        mgr.setReturn("glad", true);
        // global settlement not triggere
        mgr.setReturn("live", true);
        // make clerk ward on mgr
        mgr.setOperator(address(clerk));
        assertEq(mgr.operator(), address(clerk));
        clerk.file("buffer", 0);

        // by default interest index is up to date
        jug.setInterestUpToDate(true);
    }

    function testDebt() public {
        // 5 % interest
        // principal: 100
        // day 1: 105      (100 * 1.05)
        // day 2: 110.25   (100 * 1.05^2)
        // day 3: 115.7625 (100 * 1.05^3)

        uint256 amount = 100 ether;
        vat.increaseTab(amount);
        jug.setInterestUpToDate(false);
        uint256 rho = block.timestamp;
        jug.setReturn("ilks_rho", rho);
        uint256 interestRatePerSecond = uint256(1000000564701133626865910626); // 5 % day
        jug.setReturn("ilks_duty", interestRatePerSecond);
        hevm.warp(block.timestamp + 1 days);
        assertEq(clerk.debt(), 105 ether);
        hevm.warp(block.timestamp + 1 days);
        assertEq(clerk.debt(), 110.25 ether);

        //rate idx after two days of 5% interest
        uint256 rateIdx = rpow(interestRatePerSecond, safeSub(block.timestamp, rho), ONE);
        // simulate rate idx update
        vat.setReturn("stabilityFeeIdx", rateIdx);
        jug.setReturn("ilks_rho", block.timestamp);
        assertEq(clerk.debt(), 110.25 ether);
        hevm.warp(block.timestamp + 1 days);
        assertEq(clerk.debt(), 115.7625 ether);
    }

    function testStabilityFeeWithJug() public {
        uint256 interestRatePerSecond = uint256(1000000564701133626865910626); // 5 % day
        jug.setReturn("ilks_duty", interestRatePerSecond);

        jug.setReturn("base", 0);
        assertEq(clerk.stabilityFee(), interestRatePerSecond);

        uint256 base = ONE;
        jug.setReturn("base", base);
        assertEq(clerk.stabilityFee(), safeAdd(interestRatePerSecond, base));
    }

    function raise(uint256 amountDAI) public {
        uint256 creditlineInit = clerk.creditline();
        uint256 remainingCreditInit = clerk.remainingCredit();

        clerk.raise(amountDAI);

        // assert creditLine was increased
        assertEq(clerk.creditline(), safeAdd(creditlineInit, amountDAI));
        // assert remainingCreditLine was also increased
        assertEq(clerk.remainingCredit(), safeAdd(remainingCreditInit, amountDAI));
    }

    function draw(uint256 amountDAI, uint256 dropPrice) public {
        uint256 remainingCreditInit = clerk.remainingCredit();
        uint256 reserveDAIBalanceInit = currency.balanceOf(address(reserve));
        uint256 collatralBalanceInit = collateral.balanceOf(address(mgr));
        uint256 juniorStakeInit = clerk.juniorStake();
        uint256 overcollAmountDAI = clerk.calcOvercollAmount(amountDAI);
        uint256 protectionAmount = safeSub(overcollAmountDAI, amountDAI);
        // collateral that is required to draw the DAI from the vault -> including mkr extra protection margin
        uint256 requiredCollateral = rdiv(overcollAmountDAI, dropPrice);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);

        clerk.draw(amountDAI);

        // make sure remainingCredit decreased by drawAmount
        assertEq(clerk.remainingCredit(), safeSub(remainingCreditInit, amountDAI));
        // make sure reserve DAI balance increased by drawAmount
        assertEq(currency.balanceOf(address(reserve)), safeAdd(reserveDAIBalanceInit, amountDAI));
        // assert DROP collateral amount computed correctly and transferred to cdp
        assertEq(collateral.balanceOf(address(mgr)), safeAdd(collatralBalanceInit, requiredCollateral));
        // for testing increase ink value in vat mock
        vat.setInk(safeAdd(clerk.cdpink(), requiredCollateral));
        // assert juniorStake is correct
        assertEq(clerk.juniorStake(), safeAdd(juniorStakeInit, protectionAmount));
    }

    function wipe(uint256 amountDAI, uint256 dropPrice) public {
        uint256 tabInit = clerk.debt();
        uint256 reserveDAIBalanceInit = currency.balanceOf(address(reserve));
        uint256 mgrDAIBalanceInit = currency.balanceOf(address(mgr));
        uint256 collLockedInit = collateral.balanceOf(address(mgr));
        uint256 collateralTotalBalanceInit = collateral.totalSupply();
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);

        // repay maker debt
        clerk.wipe(amountDAI);

        // for testing set vat values correclty
        // assert collateral amount in cdp correct
        uint256 mat = clerk.mat();
        uint256 collLockedExpected = rdiv(rmul(clerk.debt(), mat), dropPrice);
        vat.setInk(collLockedExpected);

        // assert that the amount repaid is never higher than the actual debt
        if (amountDAI > tabInit) {
            amountDAI = tabInit;
        }
        // assert DAI were transferred from reserve to mgr
        assertEq(currency.balanceOf(address(mgr)), safeAdd(mgrDAIBalanceInit, amountDAI));
        assertEq(currency.balanceOf(address(reserve)), safeSub(reserveDAIBalanceInit, amountDAI));
        // assert mkr debt reduced
        assertEq(clerk.debt(), safeSub(tabInit, amountDAI));
        // assert remainingCredit is correct
        // remainingCredit can be maximum increased up to creditline value.
        // Mkr debt can grow bigger then creditline with accrued interest. When repaying mkr debt, make sure that remaining credit never exceeds creditline.
        uint256 remainingCreditExpected;
        if (clerk.debt() > clerk.creditline()) {
            remainingCreditExpected = 0;
        } else {
            remainingCreditExpected = safeSub(clerk.creditline(), clerk.debt());
        }
        assertEq(clerk.remainingCredit(), remainingCreditExpected);
        // assert juniorStake was reduced correctly
        assertEq(collateral.balanceOf(address(mgr)), collLockedExpected);
        // assert correct amount of collateral burned
        uint256 collBurnedExpected = safeSub(collLockedInit, collLockedExpected);
        assertEq(collateral.totalSupply(), safeSub(collateralTotalBalanceInit, collBurnedExpected));
        // assert senior asset value decreased by correct amount
        assertEq(assessor.values_uint("changeSeniorAsset_seniorRedeem"), rmul(collBurnedExpected, dropPrice));

        assertEq(clerk.juniorStake(), safeSub(rmul(collLockedExpected, dropPrice), clerk.debt()));
    }

    function harvest(uint256 dropPrice) public {
        uint256 collLockedInit = collateral.balanceOf(address(mgr));
        uint256 collateralTotalBalanceInit = collateral.totalSupply();
        uint256 mat = clerk.mat();

        clerk.harvest();
        // assert collateral amount in cdp correct
        uint256 collLockedExpected = rdiv(rmul(clerk.debt(), mat), dropPrice);
        assertEq(collateral.balanceOf(address(mgr)), collLockedExpected);
        // assert correct amount of collateral burned
        uint256 collBurnedExpected = safeSub(collLockedInit, collLockedExpected);
        assertEq(collateral.totalSupply(), safeSub(collateralTotalBalanceInit, collBurnedExpected));
        // assert senior asset value decreased by correct amount
        assertEq(assessor.values_uint("changeSeniorAsset_seniorRedeem"), rmul(collBurnedExpected, dropPrice));
        // for testing increase ink value in vat mock
        vat.setInk(collLockedExpected);
    }

    function heal(uint256 amount, uint256, bool full) public {
        uint256 totalBalanceDropInit = collateral.totalSupply();
        if (!full) {
            clerk.heal(amount);
        } else {
            clerk.heal();
        }
        // for testing increase ink value in vat mock
        vat.setInk(safeAdd(clerk.cdpink(), amount));
        assertEqTol(collateral.totalSupply(), safeAdd(totalBalanceDropInit, amount), "heal#1");
    }

    function sink(uint256 amountDAI) public {
        uint256 creditlineInit = clerk.creditline();
        uint256 remainingCreditInit = clerk.remainingCredit();

        uint256 reserve_ = 1000 ether;
        uint256 seniorBalance = 800 ether;
        assessor.setReturn("balance", reserve_);
        assessor.setReturn("seniorBalance", seniorBalance);
        assessor.setReturn("borrowAmountEpoch", reserve_);
        // raise creditLine
        clerk.sink(amountDAI);
        // assert creditLine was decreased
        assertEq(clerk.creditline(), safeSub(creditlineInit, amountDAI));
        // assert remainingCreditLine was also decreased
        assertEq(clerk.remainingCredit(), safeSub(remainingCreditInit, amountDAI));
    }

    function testRaise() public {
        // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validateRatioConstraints", 0);
        uint256 amountDAI = 100 ether;
        // assert calcOvercollAmount computes the correct value
        uint256 overcollAmountDAI = clerk.calcOvercollAmount(amountDAI);

        assertEq(overcollAmountDAI, 110 ether);
        // assert the security margin is computed correctly
        uint256 creditProtection = safeSub(overcollAmountDAI, amountDAI);
        assertEq(creditProtection, 10 ether);

        raise(amountDAI);
    }

    function testMultipleRaise() public {
        // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validateRatioConstraints", 0);
        uint256 amountDAI = 100 ether;
        // raise 100 DAI
        raise(amountDAI);
        // raise additional 100 DAI
        raise(amountDAI);
    }

    function testFailRaiseEpochClosing() public {
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // set validation result in coordinator to 0 -> success
        coordinator.setIntReturn("validateRatioConstraints", 0);
        uint256 amountDAI = 100 ether;
        raise(amountDAI);
    }

    function testFailRaisePoolConstraintsBroken() public {
        // set submission period in coordinator to false
        coordinator.setReturn("submissionPeriod", false);
        // set validation result in coordinator to -1 -> failure
        coordinator.setIntReturn("validateRatioConstraints", -1);
        uint256 amountDAI = 100 ether;
        raise(amountDAI);
    }

    function testFullDraw() public {
        testRaise();
        uint256 dropPrice = ONE;
        draw(clerk.creditline(), dropPrice);
    }

    function testPartialDraw() public {
        testRaise();

        uint256 dropPrice = ONE;
        // draw half creditline
        draw(safeDiv(clerk.creditline(), 2), dropPrice);
        // draw another half clerk.creditline()
        draw(safeDiv(clerk.creditline(), 2), dropPrice);
    }

    function testFailDrawAmountTooHigh() public {
        testRaise();
        uint256 dropPrice = ONE;
        // fail condition: draw amount 1 above credit line
        draw(safeAdd(clerk.creditline(), 1), dropPrice);
    }

    function testFailDrawEpochClosing() public {
        testRaise();
        uint256 dropPrice = ONE;
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // draw full amount
        draw(clerk.creditline(), dropPrice);
    }

    // function testFailDrawCollatDeficit() public {
    //     testRaise();
    //     uint dropPrice = ONE;
    //     // draw half creditline
    //     draw(safeDiv(clerk.creditline(), 2), dropPrice);
    //     clerk.file("buffer", rdiv(rmul(5, ONE), 100));
    //     // draw another half clerk.creditline()
    //     draw(safeDiv(clerk.creditline(), 2), dropPrice);
    // }

    function testFullWipe() public {
        testFullDraw();
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        vat.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint256 tab = clerk.debt();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay full debt
        wipe(tab, dropPrice);
    }

    function wipeAmountTooLow(uint256 amountDAI) public {
        testFullDraw();
        uint256 preReserve = currency.balanceOf(address(reserve));
        clerk.wipe(amountDAI);
        assertEq(currency.balanceOf(address(reserve)), preReserve);
    }

    function testWipeAmountTooLow() public {
        wipeAmountTooLow(clerk.wipeThreshold() - 1);
    }

    function testFailWipeAmountTooLow() public {
        // wipe should happen because it is exactly the threshold
        wipeAmountTooLow(clerk.wipeThreshold());
    }

    function testWipeThresholdFile() public {
        clerk.file("wipeThreshold", 123);
        assertEq(clerk.wipeThreshold(), 123);
    }

    function testPartialWipe() public {
        testFullDraw();
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        vat.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint256 tab = clerk.debt();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay 1/3 of the debt
        wipe(safeDiv(tab, 2), dropPrice);
        // repay another 1/3 of the debt
        wipe(safeDiv(tab, 4), dropPrice);
    }

    // can not wipe more then total mkr debt
    function testWipeMaxDebt() public {
        testFullDraw();
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        vat.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint256 tab = clerk.debt();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay full debt
        wipe(tab, dropPrice);
    }

    function testFailWipeNoDebt() public {
        testFullWipe();
        // try to repay again after full debt already repaid
        wipe(1 ether, ONE);
    }

    function testFailWipeEpochClosing() public {
        testFullDraw();
        // fail condiion: tset submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        vat.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint256 tab = clerk.debt();
        assertEq(tab, 110 ether);
        // make sure reserve has enough DAI
        currency.mint(address(reserve), tab);
        // repay full debt
        wipe(tab, dropPrice);
    }

    function testFailWipeNoFundsInReserve() public {
        testFullDraw();
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // increase maker debt by 10 DAI
        vat.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint256 tab = clerk.debt();
        assertEq(tab, 110 ether);
        // fail conditon: not enough DAI in reserve (only 100 DAI that were drawn before) -> 110 required
        // repay full debt
        wipe(tab, dropPrice);
    }

    function testHarvest() public {
        testFullDraw();
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
        // increase maker debt by 10 DAI
        vat.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint256 tab = clerk.debt();
        assertEq(tab, 110 ether);
        // harvest junior profit
        // 110 DROP locked -> 220 DAI
        // 220 DAI - 110 DAI (tab) - 11 (tab protectiom) => 99 DAI junior profit
        harvest(dropPrice);
    }

    function testFailHarvestEpochActive() public {
        testFullDraw();
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
        // increase maker debt by 10 DAI
        vat.increaseTab(10 ether);
        // make sure maker debt is set correclty
        uint256 tab = clerk.debt();
        assertEq(tab, 110 ether);
        // harvest junior profit
        // 110 DROP locked -> 220 DAI
        // 220 DAI - 110 DAI (tab) - 11 (tab protectiom) => 99 DAI junior profit
        harvest(dropPrice);
    }

    function testFailHarvestNoCollateralLocked() public {
        testRaise();
        // increase dropPrice
        uint256 dropPrice = safeMul(2, ONE);
        // assessor: set DROP token price
        assessor.setReturn("calcSeniorTokenPrice", dropPrice);
        // harvest junior profit
        // 110 DROP locked -> 220 DAI
        // 220 DAI - 110 DAI (tab) - 11 (tab protectiom) => 99 DAI junior profit
        harvest(dropPrice);
    }

    function testFullSink() public {
        testFullWipe();
        uint256 creditline = clerk.creditline();
        sink(creditline);
    }

    function testSinkLowerBorrowAmountEpoch() public {
        testFullWipe();
        uint256 creditline = clerk.creditline();
        assessor.setReturn("borrowAmountEpoch", creditline / 2);

        uint256 reserve_ = 1000 ether;
        uint256 seniorBalance = 800 ether;
        assessor.setReturn("balance", reserve_);
        assessor.setReturn("seniorBalance", seniorBalance);
        // raise creditLine
        clerk.sink(creditline);
        assertEq(assessor.values_uint("changeBorrowAmountEpoch"), 0);
    }

    function testPartialSink() public {
        testFullWipe();
        uint256 creditline = clerk.creditline();
        sink(safeDiv(creditline, 2));
    }

    function testFailSinkAmountTooHigh() public {
        testPartialWipe();
        uint256 creditline = clerk.creditline();
        sink(creditline);
    }

    function testFailSinkEpochClosing() public {
        testFullWipe();
        uint256 creditline = clerk.creditline();
        // fail condition: set submission period in coordinator to true
        coordinator.setReturn("submissionPeriod", true);
        sink(creditline);
    }

    function testChangeOwner() public {
        // change mgr ownership
        assertEq(mgr.owner(), address(0));
        clerk.changeOwnerMgr(address(123));
        assertEq(mgr.owner(), address(123));
    }

    function testJuniorStakeZeroWhenSoftLiquidation() public {
        testFullDraw();
        assert(clerk.juniorStake() > 0);
        mgr.setReturn("safe", false);
        assertEq(clerk.juniorStake(), 0);
    }

    function testNoJuniorStakeWhenHardLiquidation() public {
        testFullDraw();
        mgr.setReturn("glad", false);
    }

    function testNoJuniorStakeWhenGlobalSettlement() public {
        testFullDraw();
        assert(clerk.juniorStake() > 0);
        mgr.setReturn("live", false);
        assertEq(clerk.juniorStake(), 0);
    }

    function testMat() public {
        // add mat buffer of 1%
        clerk.file("buffer", 0.01 * 10 ** 27);
        uint256 mat = rdiv(rmul(150, ONE), 100); // mat value 150 %
        spotter.setReturn("mat", mat);
        // default matBuffer in clerk 1% -> assert cler.mat = 151 %
        assertEq(clerk.mat(), rdiv(rmul(151, ONE), 100));

        //increase matBuffer to 5%
        clerk.file("buffer", rdiv(rmul(5, ONE), 100));
        assertEq(clerk.mat(), rdiv(rmul(155, ONE), 100));
    }

    function testHealPartial() public {
        uint256 dropPrice = ONE;
        testFullDraw();
        // increase Mat value to 5%
        clerk.file("buffer", 0.05 * 10 ** 27);
        // additional buffer can be minted
        coordinator.setIntReturn("validateRatioConstraints", 0);

        uint256 lockedCollateralDAI = rmul(clerk.cdpink(), dropPrice);
        uint256 requiredCollateralDAI = clerk.calcOvercollAmount(clerk.debt());

        assertEq(lockedCollateralDAI, 110 ether);
        assertEq(requiredCollateralDAI, 115 ether);
        // partial healing
        uint256 healingAmount = safeDiv(safeSub(requiredCollateralDAI, lockedCollateralDAI), 2); // healing amount = 2
        assessor.setReturn("balance", 200 ether);
        heal(healingAmount, healingAmount, false);
    }

    function testHealFull() public {
        clerk.file("tolerance", 0);
        uint256 dropPrice = ONE;
        testFullDraw();
        // increase Mat value to additional 5%
        clerk.file("buffer", 0.05 * 10 ** 27);
        // additional buffer can be minted
        coordinator.setIntReturn("validateRatioConstraints", 0);

        uint256 lockedCollateralDAI = rmul(clerk.cdpink(), dropPrice);
        uint256 requiredCollateralDAI = clerk.calcOvercollAmount(clerk.debt());

        assertEq(lockedCollateralDAI, 110 ether);
        assertEqTol(requiredCollateralDAI, 115 ether, "testHealFull#1");
        // full healing
        uint256 healingAmount = safeSub(requiredCollateralDAI, lockedCollateralDAI); // healing amount = 4
        // currency in reserve for validate
        assessor.setReturn("balance", 200 ether);
        heal(healingAmount, healingAmount, true);
    }

    function testHealMaxTab() public {
        uint256 dropPrice = ONE;
        testFullDraw();
        // increase Mat value from deafault 1% to 5%
        clerk.file("buffer", rdiv(rmul(5, ONE), 100));
        // additional buffer can be minted
        coordinator.setIntReturn("validateRatioConstraints", 0);

        uint256 lockedCollateralDAI = rmul(clerk.cdpink(), dropPrice);
        uint256 requiredCollateralDAI = clerk.calcOvercollAmount(clerk.debt());

        assertEq(lockedCollateralDAI, 110 ether);
        assertEq(requiredCollateralDAI, 115 ether);
        // partial healing
        assessor.setReturn("balance", 200 ether);
        heal(10, 4, false);
    }

    function testFailHealPoolConstraintsViolated() public {
        uint256 dropPrice = ONE;
        testFullDraw();
        // increase Mat value from deafault 1% to 5%
        clerk.file("buffer", 0.05 * 10 ** 27);
        // additional buffer can be minted
        coordinator.setIntReturn("validateRatioConstraints", -1);

        uint256 lockedCollateralDAI = rmul(clerk.cdpink(), dropPrice);
        uint256 requiredCollateralDAI = clerk.calcOvercollAmount(clerk.debt());

        assertEq(lockedCollateralDAI, 111 ether);
        assertEq(requiredCollateralDAI, 115 ether);
        // partial healing
        uint256 healingAmount = safeDiv(safeSub(requiredCollateralDAI, lockedCollateralDAI), 2); // healing amount = 2
        assessor.setReturn("balance", 200 ether);
        heal(healingAmount, healingAmount, false);
    }

    function testFile() public {
        clerk.file("tolerance", 100);
        assertEq(clerk.collateralTolerance(), 100);
    }

    function testFileAutoHealMax() public {
        clerk.file("autoHealMax", 200 ether);
        assertEq(clerk.autoHealMax(), 200 ether);
    }
}
