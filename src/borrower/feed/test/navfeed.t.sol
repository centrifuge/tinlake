// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "tinlake-math/math.sol";
import "./../navfeed.sol";
import "./../../test/mock/shelf.sol";
import "./../../test/mock/pile.sol";

interface Hevm {
    function warp(uint256) external;
}

contract NAVTest is DSTest, Math {
    NAVFeed public feed;
    ShelfMock shelf;
    PileMock pile;
    uint defaultRate;
    uint defaultThresholdRatio;
    uint defaultCeilingRatio;
    uint discountRate;
    address mockNFTRegistry;
    Hevm hevm;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(123456789);
        // default values
        defaultThresholdRatio = 8*10**26;                     // 80% threshold
        defaultCeilingRatio = 6*10**26;                       // 60% ceiling
        defaultRate = uint(1000000564701133626865910626);     // 5 % day
        discountRate = uint(1000000342100000000000000000);    // 3 % day

        feed = new NAVFeed();
        pile = new PileMock();
        shelf = new ShelfMock();
        feed.depend("shelf", address(shelf));
        feed.depend("pile", address(pile));
        feed.file("discountRate", discountRate);
        mockNFTRegistry = address(42);
        feed.init();
    }

    function prepareDefaultNFT(uint tokenId, uint nftValue) public returns(bytes32) {
        return prepareDefaultNFT(tokenId, nftValue, 0);
    }

    function prepareDefaultNFT(uint tokenId, uint nftValue, uint risk) public returns(bytes32) {
        bytes32 nftID = feed.nftID(mockNFTRegistry, tokenId);
        feed.update(nftID, nftValue, risk);
        shelf.setReturn("shelf",mockNFTRegistry, tokenId);
        pile.setReturn("debt_loan", 0);
        pile.setReturn("rates_ratePerSecond", defaultRate);
        return nftID;
    }

    function borrow(uint tokenId, uint loan, uint nftValue, uint amount, uint maturityDate) internal returns(bytes32 nftID_, uint loan_, uint navIncrease_) {
        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue);
        feed.file("maturityDate",nftID, maturityDate);
        pile.setReturn("rates_ratePerSecond", uint(1000000564701133626865910626));
        uint navIncrease = feed.borrow(loan, amount);
        return (nftID, loan, navIncrease);
    }

    function borrow(uint tokenId, uint nftValue, uint amount, uint maturityDate) internal returns(bytes32 nftID_, uint loan_, uint navIncrease_) {
        // loan id doesn't matter for nav unit tests
        return borrow(tokenId, tokenId, nftValue, amount, maturityDate);
    }

    // setups the following linked list
    // time index:      [1 days] -> [2 days] -> [4 days] -> [5 days]
    //  principal:       [50 DAI] -> [50 DAI] -> [100 DAI] -> [50 DAI]
    //  tokenId & loan:  [  4   ] -> [  1   ] -> [  3   ] ->  [  2  ]
    function setupLinkedListBuckets() public {
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint dueDate = block.timestamp + 2 days;
        uint amount = 50 ether;
        uint loan = 1;

        // insert first element
        (bytes32 nft_, ,) = borrow(tokenId,loan,  nftValue, amount, dueDate);

        uint normalizedDueDate = feed.uniqueDayTimestamp(dueDate);

        uint FV = 55.125 ether; // 50 * 1.05 ^ 2 ~= 55.125
        assertEq(feed.dateBucket(normalizedDueDate), FV);

        // FV/(1.03^2)
        // list: [2 days]
        assertEq(feed.currentNAV(), 51.960741582371777180 ether);

        // insert next bucket after last bucket
        dueDate = block.timestamp + 5 days;
        tokenId = 2;
        loan = 2;
        (nft_, ,) = borrow(tokenId, loan, nftValue, amount, dueDate);

        // list : [2 days] -> [5 days]
        //50*1.05^2/(1.03^2) + 50*1.05^5/(1.03^5) ~= 107.00
        assertEq(feed.currentNAV(), 107.007702266903241118 ether);

        // insert between two buckets
        // current list: [2 days] -> [5 days]
        dueDate = block.timestamp + 4 days;
        tokenId = 3;
        loan = 3;
        (nft_, ,) = borrow(tokenId, loan, nftValue, amount, dueDate);

        // list : [2 days] ->[4 days] -> [5 days]
        //50*1.05^2/(1.03^2) + 50*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5)   ~= 161.00
        assertEq(feed.currentNAV(), 161.006075582703631092 ether);

        // insert at the beginning
        // current list: bucket[now+2days]-> bucket[now+4days] -> bucket[now+5days]
        dueDate = block.timestamp + 1 days;
        tokenId = 4;
        loan = 4;
        (nft_, ,) = borrow(tokenId, loan, nftValue, amount, dueDate);

        // list : [1 days] -> [2 days] -> [4 days] -> [5 days]
        // (50*1.05^1)/(1.03^1) + 50*1.05^2/(1.03^2) + 50*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5) ~= 211.977
        assertEq(feed.currentNAV(), 211.977019061499360158 ether);

        // add amount to existing bucket
        dueDate = block.timestamp + 4 days;
        tokenId = 5;
        loan = 5;
        (nft_, ,) = borrow(tokenId, loan, nftValue, amount, dueDate);
        // list : [1 days] -> [2 days] -> [4 days] -> [5 days]
        //(50*1.05^1)/(1.03^1) + 50*1.05^2/(1.03^2) + 100*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5)  ~= 265.97
        assertEq(feed.currentNAV(), 265.975392377299750133 ether);

    }

    function listLen() public view returns (uint) {
        uint normalizedDay = feed.uniqueDayTimestamp(block.timestamp);
        uint len = 0;

        uint currDate = normalizedDay;

        if (currDate > feed.lastBucket()) {
            return 0;
        }

        (,uint next) = feed.buckets(currDate);
        while(next == 0) {
            currDate = currDate + 1 days;
            (,next) = feed.buckets(currDate);
        }

        while(currDate != feed.NullDate())
        {
            (,currDate) = feed.buckets(currDate);
            len++;

        }
        return len;
    }

    function testSimpleBorrow() public {
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint dueDate = block.timestamp + 2 days;
        uint amount = 50 ether;
        (,,uint NAVIncrease) = borrow(tokenId, nftValue, amount, dueDate);
        // check FV
        uint normalizedDueDate = feed.uniqueDayTimestamp(dueDate);
        uint FV = 55.125 ether; // 50 * 1.05 ^ 2 = 55.125
        assertEq(feed.dateBucket(normalizedDueDate), FV);
        // FV/(1.03^2)
        assertEq(feed.currentNAV(), 51.960741582371777180 ether);
        // only on loan so current NAV should be equal to borrow increase
        assertEq(feed.currentNAV(), NAVIncrease);
        assertEq(feed.totalValue(), 51.960741582371777180 ether);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^1)
        assertEq(feed.currentNAV(), 53.519490652735515520 ether);
        assertEq(feed.totalValue(), 53.519490652735515520 ether);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^0)
        assertEq(feed.currentNAV(), 55.125 ether);
        assertEq(feed.totalValue(), 55.125 ether);
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
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint dueDate = block.timestamp + 2 days;
        uint amount = 40 ether;
        uint fixedFeeRate = 25*10**25; // 25 % -> 10 ether
        pile.setReturn("rates_fixedRate", fixedFeeRate);
        (,,uint NAVIncrease) = borrow(tokenId, nftValue, amount, dueDate);
        // // check FV
        uint normalizedDueDate = feed.uniqueDayTimestamp(dueDate);
        uint FV = 55.125 ether; // 55 * 1.05 ^ 2 = 55.125

        assertEq(feed.dateBucket(normalizedDueDate), FV);
        // FV/(1.03^2)
        assertEq(feed.currentNAV(), 51.960741582371777180 ether);
        // only on loan so current NAV should be equal to borrow increase
        assertEq(feed.currentNAV(), NAVIncrease);
        assertEq(feed.totalValue(), 51.960741582371777180 ether);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^1)
        assertEq(feed.currentNAV(), 53.519490652735515520 ether);
        assertEq(feed.totalValue(), 53.519490652735515520 ether);
        hevm.warp(block.timestamp + 1 days);
        // FV/(1.03^0)
        assertEq(feed.currentNAV(), 55.125 ether);
        assertEq(feed.totalValue(), 55.125 ether);
    }

    function testLinkedListBucket() public {
        setupLinkedListBuckets();

        hevm.warp(block.timestamp + 1 days);

        // list : [0 days] -> [1 days] -> [3 days] -> [4 days]
        //(50*1.05^1)/(1.03^0) + 50*1.05^2/(1.03^1) + 100*1.05^4/(1.03^3) + 50*1.05^5/(1.03^4)  ~= 273.95
        assertEq(feed.currentNAV(), 273.954279571404002939 ether);

        hevm.warp(block.timestamp + 1 days);

        // list : [0 days] -> [2 days] -> [3 days]
        // 50*1.05^2/(1.03^0) + 100*1.05^4/(1.03^2) + 50*1.05^5/(1.03^3) ~= 228.09
        assertEq(feed.currentNAV(), 228.097596081095759604 ether);
    }

    function testTimeOverBuckets() public {
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint dueDate = block.timestamp + 2 days;
        uint amount = 50 ether;

        // insert first element
        borrow(tokenId, nftValue, amount, dueDate);

        // 50 * 1.05^2/(1.03^2)
        assertEq(feed.currentNAV(), 51.960741582371777180 ether);

        hevm.warp(block.timestamp + 3 days);
        assertEq(feed.currentNAV(), 0);
    }

    function testNormalizeDate() public {
        uint randomUnixTimestamp = 1586977096; // 04/15/2020 @ 6:58pm (UTC)
        uint dayTimestamp = feed.uniqueDayTimestamp(randomUnixTimestamp);

        assertTrue(feed.uniqueDayTimestamp(randomUnixTimestamp) != randomUnixTimestamp);
        uint delta = randomUnixTimestamp - dayTimestamp;

        assertTrue(delta < 24*60*60);
        randomUnixTimestamp += 3 hours;
        assertTrue(feed.uniqueDayTimestamp(randomUnixTimestamp) == dayTimestamp);
    }

    function testRepay() public {
        uint amount = 50 ether;

        setupLinkedListBuckets();

        // due date + 5 days for loan 2
        uint tokenId = 2;
        uint loan = 2;
        pile.setReturn("debt_loan", amount);
        shelf.setReturn("shelf", mockNFTRegistry, tokenId);
        uint maturityDate = feed.maturityDate(feed.nftID(loan));
        uint navBefore = feed.currentNAV();

        // loan id doesn't matter because shelf is mocked
        // repay not full amount
        uint navDecrease = feed.repay(loan, 30 ether);

        listLen();

        // list : [1 days] -> [2 days] -> [4 days] -> [5 days]
        //(50*1.05^1)/(1.03^1) + (50*1.05^2) /(1.03^2)  + 100*1.05^4/(1.03^4) + (50-30)*1.05^5/(1.03^5)  ~= 232.94 eth
        assertEq(feed.currentNAV(), 232.947215966580871770 ether);
        assertEq(feed.currentNAV(), safeSub(navBefore, navDecrease));

        // newFV = (loan.debt - repayment)*interest^timeLeft
        // newFV = (50-30)*1.05^5
        uint newFV = 25.52563125 ether;
        assertEq(feed.dateBucket(maturityDate), newFV);

        uint secondAmount = 20 ether;
        pile.setReturn("debt_loan", secondAmount);
        feed.repay(loan, secondAmount);
        assertEq(feed.dateBucket(maturityDate), 0);

        //(50*1.05^1)/(1.03^1) + 100*1.05^4/(1.03^4) + 50*1.05^5/(1.03^5)  ~= 214.014
        assertEq(feed.currentNAV(), 210.928431692768286195 ether);
        // loan fully repaid -> future value = 0
        assertEq(feed.futureValue(feed.nftID(loan)), 0);
    }

    function testFailChangeMaturityDateLoanOngoing() public {
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint loan = 1;
        uint dueDate = block.timestamp + 2 days;
        uint amount = 50 ether;
        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue);
        borrow(tokenId, loan, nftValue, amount, dueDate);
        // should fail switching to new date after borrowing
        uint newDate = dueDate + 2 days;
        feed.file("maturityDate", nftID, newDate);
    }

    function testChangeMaturityDateNoDebt() public {
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint dueDate = block.timestamp + 2 days;
        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue);
        // should fail switching to new date after borrowing

        feed.file("maturityDate", nftID, dueDate);
        // no loan debt exists -> maturity date change possible
        uint newDate = dueDate + 2 days;
        feed.file("maturityDate", nftID, newDate);
        assertEq(feed.maturityDate(nftID), feed.uniqueDayTimestamp(newDate));
    }

    function testChangeMaturityDebtRepaid() public {
        // test uses loan 2
        testRepay();
        bytes32 nftID = feed.nftID(2);
        // no loan debt exists anymore -> maturity date change possible
        uint newDate = feed.maturityDate(nftID) + 2 days;
        // no loan debt exists -> maturity date change possible
        feed.file("maturityDate", nftID, newDate);
        assertEq(feed.maturityDate(nftID), feed.uniqueDayTimestamp(newDate));
    }

    function testRepayAfterMaturityDate() public {
        setupLinkedListBuckets();
        // due date + 5 days for loan 2
        uint loan = 2;
        uint repaymentAmount = 30 ether;
        bytes32 nftID = feed.nftID(loan);
        uint maturityDate = feed.maturityDate(nftID);
        uint approximatedNav = feed.approximatedNAV();
        uint futureValue = feed.futureValue(nftID);
        // assert future value of loan is bigger then 0
        assert(futureValue > 0);

        // repayment has to happen after maturity date
        hevm.warp(safeAdd(maturityDate, 1 days));

        // make repayment for overdue loan
        uint navDecrease = feed.repay(loan, repaymentAmount);
        // assert approx nav decreased by repayment amount
        assertEq(feed.approximatedNAV(), safeSub(approximatedNav, repaymentAmount));
        // assert nav decrease  equals repaymenta amount
        assertEq(navDecrease, repaymentAmount);
    }

    function testRemoveBuckets() public {
        // buckets are removed by completely repaying it
        uint[4] memory buckets = [uint(52500000000000000000), uint(55125000000000000000), uint(121550625000000000000), uint(63814078125000000000)];
        // token and loan id are the same in tests
        uint[4] memory tokenIdForBuckets = [uint(4), uint(1), uint(3), uint(2)];
        // list : [1 days] -> [2 days] -> [4 days] -> [5 days]

        setupLinkedListBuckets();
       // assertEq(listLen(), 4);

        // remove bucket in between buckets
        // remove bucket [2 days]
        uint idx = 1;
        shelf.setReturn("shelf", mockNFTRegistry, tokenIdForBuckets[idx]);

        // loan id doesn't matter because shelf is mocked
        pile.setReturn("debt_loan", buckets[idx]);
        feed.repay(tokenIdForBuckets[idx], buckets[idx]);

        assertEq(listLen(), 3);

        // remove first bucket
        // remove [1 days]
        idx = 0;
        shelf.setReturn("shelf", mockNFTRegistry, tokenIdForBuckets[idx]);
        pile.setReturn("debt_loan", buckets[idx]);
        feed.repay(tokenIdForBuckets[idx], buckets[idx]);
        assertEq(listLen(), 2);

        // remove last bucket
        // remove [5 days]
        idx = 3;
        shelf.setReturn("shelf", mockNFTRegistry, tokenIdForBuckets[idx]);
        pile.setReturn("debt_loan", buckets[idx]);
        feed.repay(tokenIdForBuckets[idx], buckets[idx]);
        assertEq(listLen(), 1);
    }

    function testWriteOffs() public {
        pile.setReturn("rate_debt", 100 ether);
        // default is two different write off groups both with 100 ether in debt
        // 60% -> 40% write off
        // 80% -> 20% write off
        // 100 ether * 0.6 + 100 ether * 0.8 = 140 ether
        assertEq(feed.currentNAV(), 140 ether);
    }

    function testRecoveryRatePD() public {
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint dueDate = block.timestamp + 2 days;
        uint amount = 50 ether;
        // risk 1 => RecoveryRatePD => 90%
        uint risk = 1;
        uint loan = 1;

        bytes32 nftID = prepareDefaultNFT(tokenId, nftValue, risk);
        feed.file("maturityDate",nftID, dueDate);

        pile.setReturn("loanRates", uint(1000000564701133626865910626));

        feed.borrow(loan, amount);

        uint normalizedDueDate = feed.uniqueDayTimestamp(dueDate);

        uint FV = 49.6125 ether; // 50 * 1.05 ^ 2  * 0.9
        assertEq(feed.dateBucket(normalizedDueDate), FV);
    }

    function testChangeRiskGroup() public {
        uint nftValue = 100 ether;
        uint tokenId = 1;
        uint loan = 1;
        uint dueDate = block.timestamp + 2 days;
        uint amount = 50 ether;

        bytes32 nftID = feed.nftID(mockNFTRegistry, tokenId);

        borrow(tokenId, loan, nftValue, amount, dueDate);

        shelf.setReturn("nftlookup" ,loan);
        pile.setReturn("debt_loan", amount);

        // check FV
        uint normalizedDueDate = feed.uniqueDayTimestamp(dueDate);

        uint FV = 55.125 ether; // 50 * 1.05 ^ 2 = 55.125
        assertEq(feed.dateBucket(normalizedDueDate), FV);

        uint defaultRisk = 0;
        feed.update(nftID, nftValue, defaultRisk);

        // should stay the same because risk class didn't change
        assertEq(feed.dateBucket(normalizedDueDate), FV);

        uint newRisk = 1;
        feed.update(nftID, nftValue, newRisk);

        //  55.125 * 0.9
        assertEq(feed.dateBucket(normalizedDueDate), 49.6125 ether);
    }

    function _repayOnMaturityDate(uint repayTimestamp, uint) internal {
        // loan 4 has maturity date in + 1 days
        uint tokenId = 4;
        uint loan = 4;
        uint amount = 50 ether;
        setupLinkedListBuckets();

        pile.setReturn("debt_loan", amount);
        shelf.setReturn("nftlookup" ,loan);
        shelf.setReturn("shelf", mockNFTRegistry, tokenId);

        uint nav = feed.currentNAV();

        feed.maturityDate(feed.nftID(tokenId));

        uint fvBucket = feed.dateBucket(feed.uniqueDayTimestamp(repayTimestamp));

        // repay on maturity date but not at 00.00 am
        hevm.warp(repayTimestamp);

        nav = feed.currentNAV();

        feed.repay(tokenId, amount);
        uint postNAV = feed.currentNAV();

        assertEq(nav, postNAV + fvBucket);
    }

    function testRepayOnMaturityDate() public {
        uint maturityDateOffset = 1 days;
        // repay on maturity date random time at the day
        _repayOnMaturityDate(feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset + 2 hours + 12 seconds, maturityDateOffset);
    }

    function testRepayOnMaturityDateLastSecond() public {
        uint maturityDateOffset = 1 days;
        // last second before overdue
        _repayOnMaturityDate(feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset + 1 days - 1 seconds, maturityDateOffset);
    }

    function testRepayOnMaturityDateMidnight() public {
        uint maturityDateOffset = 1 days;
        // repay on maturity date random time at the day
        _repayOnMaturityDate(feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset, maturityDateOffset);
    }

    function testFailRepayOnMaturityDateOneSecondTooLate() public {
        uint maturityDateOffset = 1 days;
        // repay one second too late should fail
        _repayOnMaturityDate(feed.uniqueDayTimestamp(block.timestamp) + maturityDateOffset + 1 days , maturityDateOffset);
    }
}
