// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/interest.sol";
import "../mock/shelf.sol";
import "../mock/pile.sol";
import "src/borrower/feed/navfeedPV.sol";

contract NFTFeedTest is DSTest, Math {
    NAVFeedPV public feed;
    ShelfMock shelf;
    PileMock pile;

    uint256 defaultRate;
    uint256 defaultThresholdRatio;
    uint256 defaultCeilingRatio;

    function setUp() public {
        // default values
        defaultThresholdRatio = 8 * 10 ** 26; // 80% threshold
        defaultCeilingRatio = 6 * 10 ** 26; // 60% ceiling
        defaultRate = uint256(1000000564701133626865910626); // 5 % day

        feed = new NAVFeedPV();
        pile = new PileMock();
        shelf = new ShelfMock();
        feed.depend("shelf", address(shelf));
        feed.depend("pile", address(pile));

        feed.file(
            "riskGroup",
            0, // riskGroup:       0
            8 * 10 ** 26, // thresholdRatio   70%
            6 * 10 ** 26, // ceilingRatio     60%
            uint256(1000000564701133626865910626) // interestRate     5% per year
        );

        feed.file(
            "riskGroup",
            1, // riskGroup:       0
            8 * 10 ** 26, // thresholdRatio   80%
            7 * 10 ** 26, // ceilingRatio     70%
            ONE // interestRate     1.0
        );
        feed.file(
            "riskGroup",
            2, // riskGroup:       0
            8 * 10 ** 26, // thresholdRatio   90%
            8 * 10 ** 26, // ceilingRatio     80%
            uint256(1000000003593629043335673583) // interestRate     12% per year
        );
    }

    function testUpdateNFTValues() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 value = 100 ether;
        feed.update(nftID, value);

        uint256 loan = 1;
        shelf.setReturn("shelf", address(1), 1);

        assertEq(feed.nftValues(nftID), 100 ether);
        assertEq(feed.threshold(loan), 80 ether);
        assertEq(feed.ceiling(loan), 60 ether);
    }

    function testFailUpdateNFTValuesNoPermissions() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 value = 100 ether;
        feed.deny(address(this));
        feed.update(nftID, value);
    }

    function testCreditLineCeilingOutstandingDebt() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 debt = 40 ether;
        uint256 maxCeiling = 70 ether;
        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        pile.incDebt(loan, debt);
        assertEq(feed.ceiling(loan), safeSub(maxCeiling, debt));
    }

    function testCreditLineCeilingOutstandingDebtBiggerCeiling() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 loan = 1;
        uint256 value = 100 ether;
        uint256 debt = 71 ether;
        uint256 maxCeiling = 70 ether;
        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        pile.incDebt(loan, debt);
        assertEq(feed.ceiling(loan), 0);
    }

    function testAddRiskGroup() public {
        uint256 riskGroup = 4;
        uint256 thresholdRatio = 8 * 10 ** 26;
        uint256 ceilingRatio = 8 * 10 ** 26;
        uint256 interestRate = uint256(1000000003593629043335673583);

        feed.file("riskGroup", riskGroup, thresholdRatio, ceilingRatio, interestRate);
        (uint256 pie, uint256 chi, uint256 ratePerSecond, uint256 lastUpdate, uint256 fixedRate) = pile.rates(riskGroup);

        // check nft value set correctly
        assertEq(feed.thresholdRatio(riskGroup), thresholdRatio);
        // check threshold computed correctly
        assertEq(feed.ceilingRatio(riskGroup), ceilingRatio);
        // check interestrate set correctly
        assertEq(ratePerSecond, interestRate);
    }

    function testFailAddRiskGroupNoPermissions() public {
        feed.deny(address(this)); // revoke admin permissions
        feed.file(
            "riskGroup",
            2, // riskGroup:       0
            8 * 10 ** 26, // thresholdRatio   90%
            8 * 10 ** 26, // ceilingRatio     80%
            uint256(1000000003593629043335673583) // interestRate     12% per year
        );
    }

    function testUpdateRiskGroupLoanHasNoDebt() public {
        uint256 risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 loan = 1;
        uint256 value = 100 ether;
        shelf.setReturn("shelf", address(1), 1);
        // set value and risk group of nft
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, false);

        // set new riskGroup
        uint256 defaultRisk = 0;
        feed.update(nftID, value, defaultRisk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, defaultRisk, false);
    }

    function testUpdateRiskGroupAndValueLoanHasDebt() public {
        uint256 risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 loan = 1;
        uint256 value = 100 ether;
        shelf.setReturn("shelf", address(1), 1);
        shelf.setReturn("nftlookup", loan);
        pile.setReturn("pie", 100);

        // set value and risk group of nft
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, true);

        // set new nft value & riskGroup
        value = 1000;
        risk = 0;
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, true);
    }

    function testFailUpdateRiskGroupNoPermissions() public {
        feed.deny(address(this)); // revoke admin permissions

        uint256 risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 loan = 1;
        uint256 value = 100 ether;
        shelf.setReturn("shelf", address(1), 1);
        shelf.setReturn("nftlookup", loan);
        pile.setReturn("pie", 100);

        // set value and risk group of nft
        feed.update(nftID, value, risk);
    }

    function testBorrowEvent() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 value = 100 ether;
        uint256 risk = 0;

        uint256 loan = 1;
        shelf.setReturn("shelf", address(1), 1);
        pile.setReturn("loanRates", 1);

        feed.update(nftID, value, risk);
        feed.borrowEvent(loan, 50 ether);

        assertEq(pile.values_uint("setRate_loan"), loan);
        // risk group is used as rate
        assertEq(pile.values_uint("setRate_rate"), risk);
    }

    function testBorrow() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);
        assertEq(feed.currentNAV(), maxCeiling);
        assertEq(feed.latestNAV(), maxCeiling);
    }

    function testFailBorrowAfterWriteOff() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;
        uint256 borrowAmount = 20 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, borrowAmount);
        pile.incDebt(loan, borrowAmount);
        assertEq(feed.currentNAV(), borrowAmount);
        assertEq(feed.latestNAV(), borrowAmount);

        feed.writeOff(loan);
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP());
        assertEq(feed.currentNAV(), 0);
        assertEq(feed.latestNAV(), 0);
        assert(feed.zeroPV(loan));
        feed.borrow(loan, borrowAmount); // try to borrow again
    }

    function testFailBorrowAmountTooHigh() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 debt = 40 ether;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), safeAdd(maxCeiling, 1 ether));

        feed.deny(address(this)); // revoke admin permissions
        feed.borrow(loan, maxCeiling);
    }

    function testRepay() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);
        assertEq(feed.currentNAV(), maxCeiling);
        assertEq(feed.latestNAV(), maxCeiling);

        feed.repay(loan, 50 ether);
        assertEq(feed.currentNAV(), 20 ether);
        assertEq(feed.latestNAV(), 20 ether);
    }

    function testRepayAfterWriteOff() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);
        pile.incDebt(loan, feed.ceiling(loan));
        assertEq(feed.currentNAV(), maxCeiling);
        assertEq(feed.latestNAV(), maxCeiling);

        feed.writeOff(loan);
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP());
        assertEq(feed.currentNAV(), 0);
        assertEq(feed.latestNAV(), 0);
        assert(feed.zeroPV(loan));

        feed.repay(loan, 50 ether);
        assertEq(feed.currentNAV(), 0);
        assertEq(feed.latestNAV(), 0);
    }

    function testRepayMaxNav() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);
        pile.incDebt(loan, feed.ceiling(loan));
        assertEq(feed.currentNAV(), maxCeiling);
        assertEq(feed.latestNAV(), maxCeiling);

        feed.repay(loan, 100 ether);
        assertEq(feed.currentNAV(), 0);
        assertEq(feed.latestNAV(), 0);
    }

    function testFailBorrowNoPermission() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 debt = 40 ether;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);

        feed.deny(address(this)); // revoke admin permissions
        feed.borrow(loan, maxCeiling);
    }

    // add repay tests
    function testWriteOff() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);
        pile.incDebt(loan, feed.ceiling(loan));
        assertEq(feed.currentNAV(), maxCeiling);
        assertEq(feed.latestNAV(), maxCeiling);

        feed.writeOff(loan);
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP());
        assertEq(feed.currentNAV(), 0);
        assertEq(feed.latestNAV(), 0);
        assert(feed.zeroPV(loan));
    }

    function testWriteOffMaxNav() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);
        assertEq(feed.currentNAV(), maxCeiling);
        assertEq(feed.latestNAV(), maxCeiling);

        pile.incDebt(loan, 100 ether); // writeOff more then NAV value
        feed.writeOff(loan);
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP());
        assertEq(feed.currentNAV(), 0);
        assertEq(feed.latestNAV(), 0);
        assert(feed.zeroPV(loan));
    }

    function testFailDoubleWriteOff() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 riskGroup = 1;
        uint256 value = 100 ether;
        uint256 loan = 1;
        uint256 maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);
        pile.incDebt(loan, feed.ceiling(loan));
        assertEq(feed.currentNAV(), maxCeiling);
        assertEq(feed.latestNAV(), maxCeiling);

        feed.writeOff(loan);
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP());
        assertEq(feed.currentNAV(), 0);
        assertEq(feed.latestNAV(), 0);
        feed.writeOff(loan); // fail double writeOff
    }

    function testFailWriteOffNoPermissions() public {
        uint256 risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint256 loan = 1;
        uint256 value = 100 ether;
        shelf.setReturn("shelf", address(1), 1);
        shelf.setReturn("nftlookup", loan);
        pile.setReturn("pie", 100);

        // set value and risk group of nft
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, true);

        feed.deny(address(this)); // revoke admin permissions
        feed.writeOff(loan);
    }

    function testCalcNav() public {
        bytes32 tokenId1 = feed.nftID(address(1), 1);
        bytes32 tokenId2 = feed.nftID(address(1), 2);
        bytes32 tokenId3 = feed.nftID(address(1), 3);
        uint256 value1 = 100;
        uint256 value2 = 1000;
        uint256 value3 = 10000;
        uint256 loan1 = 1;
        uint256 loan2 = 2;
        uint256 loan3 = 3;
        uint256 riskGroup = 1;

        feed.update(tokenId1, value1, riskGroup);
        feed.update(tokenId2, value2, riskGroup);
        feed.update(tokenId3, value3, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        feed.borrow(loan1, feed.ceiling(loan1));
        pile.incDebt(loan1, feed.ceiling(loan1));
        shelf.setReturn("shelf", address(1), 2);
        feed.borrow(loan2, feed.ceiling(loan2));
        pile.incDebt(loan2, feed.ceiling(loan2));
        shelf.setReturn("shelf", address(1), 3);
        feed.borrow(loan3, feed.ceiling(loan3));
        pile.incDebt(loan3, feed.ceiling(loan3));

        shelf.setReturn("loanCount", 4);
        uint256 currentNav = feed.currentNAV();
        assertEq(currentNav, safeAdd(safeAdd(70, 700), 7000));
    }

    // assertions
    function assertLoanValuesSetCorrectly(
        bytes32 nftID,
        uint256 nftValue,
        uint256 loan,
        uint256 riskGroup,
        bool loanHasDebt
    ) public {
        // check nft value set correctly
        assertEq(feed.nftValues(nftID), nftValue);
        // check threshold computed correctly
        assertEq(feed.threshold(loan), rmul(nftValue, feed.thresholdRatio(riskGroup)));
        // check ceiling computed correctly
        assertEq(feed.ceiling(loan), rmul(nftValue, feed.ceilingRatio(riskGroup)));
        // check rate set correctly in pile

        if (loanHasDebt) {
            assertEq(pile.values_uint("changeRate_loan"), loan);
            assertEq(pile.values_uint("changeRate_rate"), riskGroup);
        }
    }
}
