// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/math.sol";
import "./navfeed.tests.sol";
import "../mock/shelf.sol";
import "../mock/pile.sol";

interface Hevm {
    function warp(uint256) external;
}

contract NAVTest is Test, Math {
    TestNAVFeed public feed;
    ShelfMock shelf;
    PileMock pile;
    uint256 defaultRate;
    uint256 defaultThresholdRatio;
    uint256 defaultCeilingRatio;
    uint256 discountRate;
    address mockNFTRegistry;
    Hevm hevm;

    uint256 constant ONE_WEI_TOLERANCE = 1;

    function assertEq(uint256 x, uint256 y, uint256 weiTolerance) public {
        uint256 diff = 0;
        if (x > y) {
            diff = safeSub(x, y);
        }
        diff = safeSub(y, x);
        assertTrue(diff <= weiTolerance);
    }

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(123456789);
        // default values
        defaultThresholdRatio = 8 * 10 ** 26; // 80% threshold
        defaultCeilingRatio = 6 * 10 ** 26; // 60% ceiling
        defaultRate = uint256(1000000564701133626865910626); // 5 % day
        discountRate = uint256(1000000342100000000000000000); // 3 % day

        feed = new TestNAVFeed();
        pile = new PileMock();
        shelf = new ShelfMock();
        feed.depend("shelf", address(shelf));
        feed.depend("pile", address(pile));
        feed.file("discountRate", discountRate);
        mockNFTRegistry = address(42);
        feed.init();
    }

    function prepareDefaultNFT(uint256 tokenId, uint256 nftValue) public returns (bytes32) {
        return prepareDefaultNFT(tokenId, nftValue, 0);
    }

    function prepareDefaultNFT(uint256 tokenId, uint256 nftValue, uint256 risk) public returns (bytes32) {
        bytes32 nftID = feed.nftID(mockNFTRegistry, tokenId);
        feed.update(nftID, nftValue, risk);
        shelf.setReturn("shelf", mockNFTRegistry, tokenId);
        pile.incDebt(tokenId, 0);
        pile.setReturn("rates_ratePerSecond", defaultRate);
        return nftID;
    }

    function borrow(uint256 tokenId, uint256 loan, uint256 nftValue, uint256 amount, uint256 maturityDate)
        internal
        returns (bytes32 nftID_, uint256 loan_, uint256 navIncrease_)
    {
        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue);
        feed.file("maturityDate", nftID, maturityDate);
        pile.setReturn("rates_ratePerSecond", uint256(1000000564701133626865910626));
        uint256 navIncrease = feed.borrow(loan, amount);
        return (nftID, loan, navIncrease);
    }

    function borrow(uint256 tokenId, uint256 nftValue, uint256 amount, uint256 maturityDate)
        internal
        returns (bytes32 nftID_, uint256 loan_, uint256 navIncrease_)
    {
        // loan id doesn't matter for nav unit tests
        return borrow(tokenId, tokenId, nftValue, amount, maturityDate);
    }

    // setups the following linked list
    // time index:      [1 days] -> [2 days] -> [4 days] -> [5 days]
    //  principal:       [50 DAI] -> [50 DAI] -> [100 DAI] -> [50 DAI]
    //  tokenId & loan:  [  4   ] -> [  1   ] -> [  3   ] ->  [  2  ]
    function setupLinkedListBuckets() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 50 ether;
        uint256 loan = 1;

        // insert first element
        (bytes32 nft_,,) = borrow(tokenId, loan, nftValue, amount, dueDate);

        uint256 normalizedDueDate = feed.uniqueDayTimestamp(dueDate);

        uint256 FV = 55.125 ether; // 50 * 1.05 ^ 2 ~= 55.125
        assertEq(feed.buckets(normalizedDueDate), FV);

        // FV/(1.03^2)
        // list: [2 days]
        assertEq(feed.currentNAV(), 51.96074158237177718 ether);

        // insert next bucket after last bucket
        dueDate = block.timestamp + 5 days;
        tokenId = 2;
        loan = 2;
        (nft_,,) = borrow(tokenId, loan, nftValue, amount, dueDate);

        // list : [2 days] -> [5 days]
        //50*1.05^2/(1.03^2) + 50*1.05^5/(1.03^5) ~= 107.00
        assertEq(feed.currentNAV(), 107.007702266903241118 ether);

        // insert between two buckets
        // current list: [2 days] -> [5 days]
        dueDate = block.timestamp + 4 days;
        tokenId = 3;
        loan = 3;
        (nft_,,) = borrow(tokenId, loan, nftValue, amount, dueDate);

        // list : [2 days] ->[4 days] -> [5 days]
        //50*1.05^2/(1.03^2) + 50*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5)   ~= 161.00
        assertEq(feed.currentNAV(), 161.006075582703631092 ether);

        // insert at the beginning
        // current list: bucket[now+2days]-> bucket[now+4days] -> bucket[block.timestamp+5days]
        dueDate = block.timestamp + 1 days;
        tokenId = 4;
        loan = 4;
        (nft_,,) = borrow(tokenId, loan, nftValue, amount, dueDate);

        // list : [1 days] -> [2 days] -> [4 days] -> [5 days]
        // (50*1.05^1)/(1.03^1) + 50*1.05^2/(1.03^2) + 50*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5) ~= 211.977
        assertEq(feed.currentNAV(), 211.977019061499360158 ether);

        // add amount to existing bucket
        dueDate = block.timestamp + 4 days;
        tokenId = 5;
        loan = 5;
        (nft_,,) = borrow(tokenId, loan, nftValue, amount, dueDate);
        // list : [1 days] -> [2 days] -> [4 days] -> [5 days]
        //(50*1.05^1)/(1.03^1) + 50*1.05^2/(1.03^2) + 100*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5)  ~= 265.97
        assertEq(feed.currentNAV(), 265.975392377299750133 ether, ONE_WEI_TOLERANCE);
    }

    function testSimpleBorrow() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 50 ether;
        (,, uint256 NAVIncrease) = borrow(tokenId, nftValue, amount, dueDate);
        // check FV
        uint256 normalizedDueDate = feed.uniqueDayTimestamp(dueDate);
        uint256 FV = 55.125 ether; // 50 * 1.05 ^ 2 = 55.125
        assertEq(feed.buckets(normalizedDueDate), FV);
        // FV/(1.03^2)
        assertEq(feed.currentNAV(), 51.96074158237177718 ether, ONE_WEI_TOLERANCE);
        // only on loan so current NAV should be equal to borrow increase
        assertEq(feed.currentNAV(), NAVIncrease);
        assertEq(feed.currentNAV(), 51.96074158237177718 ether, ONE_WEI_TOLERANCE);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^1)
        assertEq(feed.currentNAV(), 53.51949065273551552 ether, ONE_WEI_TOLERANCE);
        assertEq(feed.currentNAV(), 53.51949065273551552 ether, ONE_WEI_TOLERANCE);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^0)
        assertEq(feed.currentNAV(), 55.125 ether, ONE_WEI_TOLERANCE);
        assertEq(feed.currentNAV(), 55.125 ether, ONE_WEI_TOLERANCE);
    }

    // function testMultipleBorrow() public {
    //     uint nftValue = 100 ether;
    //     uint tokenId = 1;
    //     uint dueDate = block.timestamp + 2 days;

    //     uint firstBorrowAmount = 30 ether;
    //     (, uint loan,uint firstNavIncrease) = borrow(tokenId, nftValue, firstBorrowAmount, dueDate);
    //     assertEq(feed.currentNAV(), firstNavIncrease);

    //     uint secondBorrowAmount = 20 ether;
    //     uint secondNavIncrease = feed.borrow(loan, secondBorrowAmount);
    //     assertEq(feed.currentNAV(), firstNavIncrease + secondNavIncrease);
    // }

    function testBorrowWithFixedFee() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 40 ether;
        uint256 fixedFeeRate = 25 * 10 ** 25; // 25 % -> 10 ether
        pile.setReturn("rates_fixedRate", fixedFeeRate);
        (,, uint256 NAVIncrease) = borrow(tokenId, nftValue, amount, dueDate);
        // // check FV
        uint256 normalizedDueDate = feed.uniqueDayTimestamp(dueDate);
        uint256 FV = 55.125 ether; // 55 * 1.05 ^ 2 = 55.125

        assertEq(feed.buckets(normalizedDueDate), FV);
        // FV/(1.03^2)
        assertEq(feed.currentNAV(), 51.96074158237177718 ether, ONE_WEI_TOLERANCE);
        // only on loan so current NAV should be equal to borrow increase
        assertEq(feed.currentNAV(), NAVIncrease);
        assertEq(feed.currentNAV(), 51.96074158237177718 ether, ONE_WEI_TOLERANCE);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^1)
        assertEq(feed.currentNAV(), 53.51949065273551552 ether, ONE_WEI_TOLERANCE);
        assertEq(feed.currentNAV(), 53.51949065273551552 ether, ONE_WEI_TOLERANCE);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^0)
        assertEq(feed.currentNAV(), 55.125 ether, ONE_WEI_TOLERANCE);
        assertEq(feed.currentNAV(), 55.125 ether, ONE_WEI_TOLERANCE);
    }

    function testTimeOverBuckets() public {
        uint256 nftValue = 100 ether;
        uint256 loan = 1;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 50 ether;

        // insert first element
        borrow(tokenId, loan, nftValue, amount, dueDate);

        // 50 * 1.05^2/(1.03^2)
        assertEq(feed.currentNAV(), 51.96074158237177718 ether);

        hevm.warp(block.timestamp + 3 days);
        feed.overrideWriteOff(loan, 3); // 100% write off

        assertEq(feed.currentNAV(), 0);
    }

    function testNormalizeDate() public {
        uint256 randomUnixTimestamp = 1586977096; // 04/15/2020 @ 6:58pm (UTC)
        uint256 dayTimestamp = feed.uniqueDayTimestamp(randomUnixTimestamp);

        assertTrue(feed.uniqueDayTimestamp(randomUnixTimestamp) != randomUnixTimestamp);
        uint256 delta = randomUnixTimestamp - dayTimestamp;

        assertTrue(delta < 24 * 60 * 60);
        randomUnixTimestamp += 3 hours;
        assertTrue(feed.uniqueDayTimestamp(randomUnixTimestamp) == dayTimestamp);
    }

    // gas consumption
    // 100    loans = 984822
    // 500    loans = 5426989
    // 1000   loans = 10835851
    function recalcDiscount(uint256 discountRate_, uint256 expectedTotalDiscount) public {
        // file new discountRate to trigger navRecalc
        feed.file("discountRate", discountRate_);
        assertTrue(expectedTotalDiscount == feed.latestDiscount());
    }

    // checks if optimized and unoptimized totalDiscount computations return the same value
    // -> the result of reCalcTotalDiscount & currentPVs have to compute the same totalDiscount value for the same discountRate
    function testRecalcDiscount() public {
        uint256 loanCount = 100;
        uint256 discountRate_ = defaultRate; // 5% per day
        feed.file("discountRate", discountRate_);
        shelf.setReturn("loanCount", loanCount);

        // create loans
        for (uint256 i = 1; i < loanCount; i++) {
            uint256 nftValue = 100 ether;
            uint256 tokenId = i;
            uint256 dueDate = block.timestamp + (1 days * i);
            uint256 amount = 50 ether;
            uint256 risk = 1;
            uint256 loan = i;
            bytes32 nftID = prepareDefaultNFT(tokenId, nftValue, risk);
            borrow(tokenId, loan, nftValue, amount, dueDate);
        }
        // file the same discount rate to trigger the updateDiscountRate routine -> totalDiscount value should stay unchanged
        recalcDiscount(discountRate_, feed.latestDiscount());

        hevm.warp(block.timestamp + 2 days);
    }

    function testChangeDiscountRate() public {
        uint256 loanCount = 100;
        feed.file("discountRate", defaultRate); // file default rate 5% day
        shelf.setReturn("loanCount", loanCount);

        // create loans
        for (uint256 i = 1; i < loanCount; i++) {
            uint256 nftValue = 100 ether;
            uint256 tokenId = i;
            uint256 dueDate = block.timestamp + (1 days * i);
            uint256 amount = 50 ether;
            uint256 risk = 1;
            uint256 loan = i;
            bytes32 nftID = prepareDefaultNFT(tokenId, nftValue, risk);
            borrow(tokenId, loan, nftValue, amount, dueDate);
        }
        assertTrue(feed.latestDiscount() == 4950000000000000000000);
        assertTrue(feed.latestNAV() == 4950000000000000000000);
        // change discountRate -> file new fee 3% day
        uint256 expectedTotalDiscount = 33229158876667979731935;
        recalcDiscount(discountRate, expectedTotalDiscount);
        assertTrue(feed.latestNAV() == expectedTotalDiscount);
    }

    function testRepay() public {
        uint256 amount = 50 ether;

        setupLinkedListBuckets();

        // due date + 5 days for loan 2
        uint256 tokenId = 2;
        uint256 loan = 2;
        pile.incDebt(loan, amount);
        shelf.setReturn("shelf", mockNFTRegistry, tokenId);
        uint256 maturityDate = feed.maturityDate(feed.nftID(loan));

        // loan id doesn't matter because shelf is mocked
        // repay not full amount
        feed.repay(loan, 30 ether);

        // list : [1 days] -> [2 days] -> [4 days] -> [5 days]
        //(50*1.05^1)/(1.03^1) + (50*1.05^2) /(1.03^2)  + 100*1.05^4/(1.03^4) + (50-30)*1.05^5/(1.03^5)  ~= 232.94 eth
        assertEq(feed.currentNAV(), 232.94721596658087177 ether, ONE_WEI_TOLERANCE);

        // newFV = (loan.debt - repayment)*interest^timeLeft
        // newFV = (50-30)*1.05^5
        uint256 newFV = 25.52563125 ether;
        assertEq(feed.buckets(maturityDate), newFV);

        uint256 secondAmount = 20 ether;
        pile.incDebt(loan, secondAmount);
        feed.repay(loan, secondAmount);
        assertEq(feed.buckets(maturityDate), 0);

        //(50*1.05^1)/(1.03^1) + 100*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5)  ~= 214.014
        assertEq(feed.currentNAV(), 210.928431692768286195 ether, ONE_WEI_TOLERANCE);
        // loan fully repaid -> future value = 0
        assertEq(feed.futureValue(feed.nftID(loan)), 0);
    }

    function testFailChangeMaturityDateLoanOngoing() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 loan = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 50 ether;
        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue);
        borrow(tokenId, loan, nftValue, amount, dueDate);
        // should fail switching to new date after borrowing
        uint256 newDate = dueDate + 2 days;
        feed.file("maturityDate", nftID, newDate);
    }

    function testChangeMaturityDateNoDebt() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 2 days;
        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue);
        // should fail switching to new date after borrowing

        feed.file("maturityDate", nftID, dueDate);
        // no loan debt exists -> maturity date change possible
        uint256 newDate = dueDate + 2 days;
        feed.file("maturityDate", nftID, newDate);
        assertEq(feed.maturityDate(nftID), feed.uniqueDayTimestamp(newDate));
    }

    function testOverdueLoan() public {
        feed.file("discountRate", defaultRate); // discount rate == financing fee

        // 1 loan due far in the future, with a borrow amount of 100
        uint256 nftValue = 200 ether;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 10 days;
        uint256 amount = 100 ether;
        uint256 loan = 1;

        borrow(tokenId, loan, nftValue, amount, dueDate);

        // 1 loan due in 2 days, with a borrow amount of 20
        borrow(2, 2, 40 ether, 20 ether, block.timestamp + 2 days);

        hevm.warp(block.timestamp + 1 days);
        feed.calcUpdateNAV();
        assertEq(feed.currentNAV(), 126 ether); // 100 * 1.05 ^ 1 + 20 * 1.05^1 = 126

        // loan 2 is 1 day over due, last NAV update was 1 day before the maturity date
        hevm.warp(block.timestamp + 2 days);
        feed.calcUpdateNAV();
        assertEq(feed.currentNAV(), 137.8125 ether); // 100 * 1.05 ^ 3 + 20 * 1.05^2 = 137.8125
    }

    function testRepayAfterMaturityDate() public {
        setupLinkedListBuckets();
        // due date + 5 days for loan 2
        uint256 loan = 2;
        uint256 repaymentAmount = 30 ether;
        bytes32 nftID = feed.nftID(loan);
        uint256 maturityDate = feed.maturityDate(nftID);
        uint256 nav = feed.currentNAV();
        uint256 futureValue = feed.futureValue(nftID);
        // assert future value of loan is bigger then 0
        assert(futureValue > 0);

        // repayment has to happen after maturity date
        hevm.warp(safeAdd(maturityDate, 1 days));

        // make repayment for overdue loan
        uint256 preNAV = feed.currentNAV();

        pile.incDebt(loan, repaymentAmount);
        feed.repay(loan, repaymentAmount);

        // overdue but not written-off case
        assertTrue(preNAV > feed.currentNAV());
    }

    function testPartialRepayAfterMaturityDate() public {
        setupLinkedListBuckets();
        uint256 loan = 2;
        uint256 amount = 30 ether;
        bytes32 nftID = feed.nftID(loan);
        uint256 maturityDate = feed.maturityDate(nftID);

        // repayment has to happen after maturity date
        hevm.warp(safeAdd(maturityDate, 1 days));

        // make partial repayment for overdue loan
        pile.incDebt(loan, amount);

        uint256 preNAV = feed.currentNAV();
        feed.repay(loan, 15 ether); // repay 50%
        assertTrue(feed.currentNAV() < preNAV);
    }

    function testPartialRepayHigherThenFvAfterMaturityDate() public {
        setupLinkedListBuckets();
        uint256 loan = 1;
        bytes32 nftID = feed.nftID(loan);
        uint256 maturityDate = feed.maturityDate(nftID);
        uint256 debt = 162 ether; // overdue debt is higher then the FV
        uint256 repaymentAmount = 60 ether; // repayment amount higher then FV, but lower then actual debt

        // repayment has to happen after maturity date
        hevm.warp(safeAdd(maturityDate, 1 days));

        // make partial repayment for overdue loan
        pile.incDebt(loan, debt);

        uint256 preNAV = feed.currentNAV();
        feed.repay(loan, repaymentAmount);
        assertTrue(feed.currentNAV() == preNAV);
    }

    function testWriteOffOnMaturityDate() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 50 ether;
        uint256 loan = 1;

        borrow(tokenId, loan, nftValue, amount, dueDate);

        hevm.warp(block.timestamp + 3 days);

        pile.incDebt(loan, 55.125 ether); // 50 * 1.05^2 = 55.125

        uint256 pre = feed.currentWriteOffs();
        feed.overrideWriteOff(loan, 1); // 50% writeoff
        pile.setReturn("rate_debt", (27.5625 ether));
        uint256 post = feed.currentWriteOffs();

        assertTrue(post > pre);
    }

    function testRecoveryRatePD() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 50 ether;
        // risk 1 => RecoveryRatePD => 90%
        uint256 risk = 1;
        uint256 loan = 1;

        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue, risk);
        feed.file("maturityDate", nftID, dueDate);

        pile.setReturn("loanRates", uint256(1000000564701133626865910626));

        feed.borrow(loan, amount);

        uint256 normalizedDueDate = feed.uniqueDayTimestamp(dueDate);

        uint256 FV = 49.6125 ether; // 50 * 1.05 ^ 2  * 0.9
        assertEq(feed.buckets(normalizedDueDate), FV);
    }

    function testChangeRiskGroup() public {
        uint256 nftValue = 100 ether;
        uint256 tokenId = 1;
        uint256 loan = 1;
        uint256 dueDate = block.timestamp + 2 days;
        uint256 amount = 50 ether;

        bytes32 nftID = feed.nftID(mockNFTRegistry, tokenId);

        borrow(tokenId, loan, nftValue, amount, dueDate);

        shelf.setReturn("nftlookup", loan);
        pile.incDebt(loan, amount);

        // check FV
        uint256 normalizedDueDate = feed.uniqueDayTimestamp(dueDate);

        uint256 FV = 55.125 ether; // 50 * 1.05 ^ 2 = 55.125

        assertEq(feed.buckets(normalizedDueDate), FV);

        uint256 defaultRisk = 0;
        feed.update(nftID, nftValue, defaultRisk);

        // should stay the same because risk class didn't change
        assertEq(feed.buckets(normalizedDueDate), FV);

        uint256 NAV = feed.latestNAV();
        uint256 newRisk = 1;

        feed.update(nftID, nftValue, newRisk);

        uint256 newFV = 49.6125 ether;
        uint256 newNAV = feed.calcDiscount(
            feed.discountRate(), newFV, feed.uniqueDayTimestamp(block.timestamp), feed.maturityDate(nftID)
        );

        //  55.125 * 0.9
        assertEq(feed.buckets(normalizedDueDate), newFV);
        assertEq(feed.latestNAV(), newNAV);
        assertEq(feed.latestDiscount(), newNAV);
    }

    function _repayOnMaturityDate(uint256 repayTimestamp, uint256) internal {
        // loan 4 has maturity date in + 1 days
        uint256 tokenId = 4;
        uint256 loan = 4;
        uint256 amount = 50 ether;
        setupLinkedListBuckets();

        pile.incDebt(loan, amount);
        shelf.setReturn("nftlookup", loan);
        shelf.setReturn("shelf", mockNFTRegistry, tokenId);

        uint256 nav = feed.currentNAV();

        feed.maturityDate(feed.nftID(tokenId));

        uint256 fvBucket = feed.buckets(feed.uniqueDayTimestamp(repayTimestamp));

        // repay on maturity date but not at 00.00 am
        hevm.warp(repayTimestamp);

        nav = feed.currentNAV();

        feed.repay(tokenId, amount);
        uint256 postNAV = feed.currentNAV();

        assertEq(nav, postNAV + fvBucket);
    }

    function testRepayOnMaturityDate() public {
        uint256 maturityDateOffset = 1 days;
        // repay on maturity date random time at the day
        _repayOnMaturityDate(
            feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset + 2 hours + 12 seconds, maturityDateOffset
        );
    }

    function testRepayOnMaturityDateLastSecond() public {
        uint256 maturityDateOffset = 1 days;
        // last second before overdue
        _repayOnMaturityDate(
            feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset + 1 days - 1 seconds, maturityDateOffset
        );
    }

    function testRepayOnMaturityDateMidnight() public {
        uint256 maturityDateOffset = 1 days;
        // repay on maturity date random time at the day
        _repayOnMaturityDate(feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset, maturityDateOffset);
    }

    function testFailRepayOnMaturityDateOneSecondTooLate() public {
        uint256 maturityDateOffset = 1 days;
        // repay one second too late should fail
        _repayOnMaturityDate(feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset + 1 days, maturityDateOffset);
    }

    // 6% interest rate & 25% write off
    // file("writeOffGroup", uint(1000000674400000000000000000), 75 * 10**25, 30);
    // 6% interest rate & 50% write off
    // file("writeOffGroup", uint(1000000674400000000000000000), 50 * 10**25, 60);
    // 6% interest rate & 75% write off
    // file("writeOffGroup", uint(1000000674400000000000000000), 25 * 10**25, 90);
    // 6% interest rate & 100% write off
    // file("writeOffGroup", uint(1000000674400000000000000000), 0, 120);
    function testPublicWriteOff() public {
        // create loan
        uint256 nftValue = 100 ether;
        uint256 dueDate = block.timestamp + (4 days);
        uint256 amount = 50 ether;
        uint256 risk = 1;
        uint256 loan = 1;
        uint256 tokenID = 1;
        prepareDefaultNFT(tokenID, nftValue, risk);
        shelf.setReturn("loanCount", 2);
        borrow(tokenID, loan, nftValue, amount, dueDate);

        // loan overdue after 5 days
        hevm.warp(block.timestamp + 35 days); // -> group 1000]
        pile.incDebt(loan, 60 ether);
        feed.writeOff(loan);
        assertEq(feed.latestNAV(), 45 ether); // NAV includes debt * writeoff factor
        // check pile calls with correct writeOff rate
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP_START());

        hevm.warp(block.timestamp + 30 days); // -> group 1001
        feed.writeOff(loan);
        // check pile calls with correct writeOff rate
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP_START() + 1);

        hevm.warp(block.timestamp + 30 days); // -> group 1002
        feed.writeOff(loan);
        // check pile calls with correct writeOff rate
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP_START() + 2);
    }

    function testFailWriteOffHealthyLoan() public {
        // create loan
        uint256 nftValue = 100 ether;
        uint256 dueDate = block.timestamp + (4 days);
        uint256 amount = 50 ether;
        uint256 risk = 1;
        uint256 loan = 1;
        uint256 tokenID = 1;
        bytes32 nftID = prepareDefaultNFT(tokenID, nftValue, risk);
        shelf.setReturn("loanCount", 2);
        borrow(tokenID, loan, nftValue, amount, dueDate);

        // should fail as loan is not overdue yet
        feed.writeOff(loan);
    }

    function testFailOverrideWriteOffHealthyLoan() public {
        // create loan
        uint256 nftValue = 100 ether;
        uint256 dueDate = block.timestamp + (4 days);
        uint256 amount = 50 ether;
        uint256 risk = 1;
        uint256 loan = 1;
        uint256 tokenID = 1;
        bytes32 nftID = prepareDefaultNFT(tokenID, nftValue, risk);
        shelf.setReturn("loanCount", 2);
        borrow(tokenID, loan, nftValue, amount, dueDate);

        // should also fail, even admins cant writeoff non overdue loans
        feed.overrideWriteOff(loan, 0);
    }

    function fileWriteOffGroup(uint256 percentage, uint256 overdueDays, uint256 index) public {
        feed.file("writeOffGroup", percentage, 0, overdueDays);
        (uint256 p, uint256 o) = feed.writeOffGroups(index);

        assertTrue(pile.values_uint("file_rate") == safeAdd(feed.WRITEOFF_RATE_GROUP_START(), index));
        assertTrue(pile.values_uint("file_ratePerSecond") == percentage);
        assertTrue(p == 0);
        assertTrue(overdueDays == o);
    }

    function testFileWriteOff(uint128 overdueDays) public {
        if (overdueDays <= 120) {
            return;
        }
        // 4 default writeoff Groups exist: 1000 - 1003
        uint256 expectedIndex = 4;
        fileWriteOffGroup(uint256(1000000674400000000000000000), overdueDays, expectedIndex);
    }
}
