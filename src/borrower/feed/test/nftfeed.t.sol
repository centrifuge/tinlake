// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "tinlake-math/interest.sol";
import "./../principal.sol";
import "./../../test/mock/shelf.sol";
import "./../../test/mock/pile.sol";


contract NFTFeedTest is DSTest, Math {
    PrincipalNAVFeed public feed;
    ShelfMock shelf;
    PileMock pile;

    uint defaultRate;
    uint defaultThresholdRatio;
    uint defaultCeilingRatio;

    function setUp() public {
        // default values
        defaultThresholdRatio = 8*10**26;                     // 80% threshold
        defaultCeilingRatio = 6*10**26;                       // 60% ceiling
        defaultRate = uint(1000000564701133626865910626);     // 5 % day

        feed = new PrincipalNAVFeed();
        pile = new PileMock();
        shelf = new ShelfMock();
        feed.depend("shelf", address(shelf));
        feed.depend("pile", address(pile));
        // init scorecard only for NFT Feed
        init();
    }

    function init() public {
        // risk group  => 0
        // thresholdRatio => 80%
        // ceilingRatio => 60%
        // interestRatio: 0%
        feed.file("riskGroupNFT",0, 8*10**26, 6*10**26, ONE);

        // risk group  => 1
        // thresholdRatio => 70%
        // ceilingRatio => 50%
        // interestRate => 12 % per year
        feed.file("riskGroupNFT", 1, 7*10**26, 5*10**26, uint(1000000003593629043335673583));

        // risk group  => 2
        // thresholdRatio => 70%
        // ceilingRatio => 50%
        // interestRate => 5 % per day
        feed.file("riskGroupNFT", 2, 7*10**26, 5*10**26, uint(1000000564701133626865910626));

        // risk group  => 3
        // ceiling ratio => 100%
        // thresholdRatio => 70%
        // interest rate => 5% per day
        feed.file("riskGroupNFT", 3, 7*10**26, ONE, uint(1000000564701133626865910626));

        // risk group => 4 (used by collector tests)
        // ceiling ratio => 50%
        // thresholdRatio => 60%
        // interest rate => 5% per day
        feed.file("riskGroupNFT", 4, 6*10**26, 5*10**26, uint(1000000564701133626865910626));
    }

    function testBasicNFT() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint value = 100 ether;
        feed.update(nftID, value);

        uint loan = 1;
        shelf.setReturn("shelf",address(1), 1);

        assertEq(feed.nftValues(nftID), 100 ether);
        assertEq(feed.threshold(loan), 80 ether);
        assertEq(feed.ceiling(loan), 60 ether);
    }

    function assertLoanValuesSetCorrectly(bytes32 nftID, uint nftValue, uint loan, uint riskGroup, bool loanHasDebt) public {
        // check nft value set correctly
        assertEq(feed.nftValues(nftID), nftValue);
        // check threshold computed correctly
        assertEq(feed.threshold(loan), rmul(nftValue, feed.thresholdRatio(riskGroup)));
        // check ceiling computed correctly
        assertEq(feed.ceiling(loan),  rmul(nftValue, feed.ceilingRatio(riskGroup)));
        // check rate set correctly in pile

        if (loanHasDebt) {
            assertEq(pile.values_uint("changeRate_loan"), loan);
            assertEq(pile.values_uint("changeRate_rate"), riskGroup);
        }
    }

    function testUpdateRiskGroupLoanHasNoDebt() public {
        // risk group  => 1
        // thresholdRatio => 70%
        // ceilingRatio => 50%
        // interestRate => 12 % per year
        uint risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;
        shelf.setReturn("shelf", address(1), 1);
        // set value and risk group of nft
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, false);

        // set new riskGroup
        uint defaultRisk = 0;
        feed.update(nftID, value, defaultRisk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, defaultRisk, false);
    }

    function testUpdateNFTValueLoanHasNoDebt() public {
        // risk group  => 1
        // thresholdRatio => 70%
        // ceilingRatio => 50%
        // interestRate => 12 % per year
        uint risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;

        shelf.setReturn("shelf", address(1), 1);
        // set value and risk group of nft
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, false);

        // set new nft value
        value = 1000;
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, false);
    }

    function testUpdateRiskGroupAndValueLoanHasDebt() public {
        // risk group  => 1
        // thresholdRatio => 70%
        // ceilingRatio => 50%
        // interestRate => 12 % per year
        uint risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;
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
        // // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, true);
     }

    function testFailUpdateRiskGroupDoesNotExist() public {
        // risk group does not exist
        uint risk = 1000;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;

        // set value and risk group of nft
        feed.update(nftID, value, risk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, false);

        // set new riskGroup
        uint defaultRisk = 0;
        feed.update(nftID, value, defaultRisk);
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, defaultRisk, false);
    }

    function testBorrowEvent() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint value = 100 ether;
        uint risk = 0;

        uint loan = 1;
        shelf.setReturn("shelf",address(1), 1);
        pile.setReturn("loanRates", 1);

        feed.update(nftID, value, risk);
        feed.borrowEvent(loan);
        assertEq(pile.values_uint("setRate_loan"), loan);
        // risk group is used as rate
        assertEq(pile.values_uint("setRate_rate"), risk);
    }

    function testCeiling() public {
        // risk group  => 1
        // thresholdRatio => 70%
        // ceilingRatio => 50%
        // interestRate => 12 % per year
        uint risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;
        shelf.setReturn("shelf",address(1), 1);

        feed.update(nftID, value, risk);

        // total ceiling for risk group 1
        uint maxCeiling = 50 ether;
        assertEq(feed.ceiling(loan), maxCeiling);
        uint amount = 20 ether;
        feed.borrow(loan, amount);

        // total ceiling for risk group 1
        assertEq(feed.ceiling(loan), safeSub(maxCeiling,amount));

        feed.borrow(loan, safeSub(maxCeiling,amount));

        assertEq(feed.ceiling(loan), 0);
    }

    function testUpdateNFTCeilingExceedsBorrowedAmount() public {
        // risk group  => 1
        // thresholdRatio => 70%
        // ceilingRatio => 50%
        // interestRate => 12 % per year
        uint risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;
        shelf.setReturn("shelf",address(1), 1);

        // set nft value & risk group
        feed.update(nftID, value, risk);

        // assert values
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, false);


        uint maxCeiling = feed.ceiling(loan);
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling);

        // decrease nft value, which leads to ceiling decrease
        value = safeDiv(value, 2);
        // set new nft value
        feed.update(nftID, value);

        // assert new value was set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, false);
        // new ceiling is smaller then already borrowed amount -> shoul return 0

        assertEq(feed.ceiling(loan), 0);
    }

    function testFailBorrowTooHigh() public {
        // risk group
        uint risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;
        shelf.setReturn("shelf",address(1), 1);

        feed.update(nftID, value, risk);

        uint maxCeiling = 50 ether;
        assertEq(feed.ceiling(loan), maxCeiling);
        feed.borrow(loan, maxCeiling+1);
    }

}
