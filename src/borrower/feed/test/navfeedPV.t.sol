// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";
import "tinlake-math/interest.sol";
import "./../../test/mock/shelf.sol";
import "./../../test/mock/pile.sol";
import "../navfeedPV.sol";


contract NFTFeedTest is DSTest, Math {
    NAVFeedPV public feed;
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

        feed = new NAVFeedPV();
        pile = new PileMock();
        shelf = new ShelfMock();
        feed.depend("shelf", address(shelf));
        feed.depend("pile", address(pile));
        
        feed.file("riskGroup",
            0,                                      // riskGroup:       0
            8*10**26,                               // thresholdRatio   70%
            6*10**26,                               // ceilingRatio     60%
            uint(1000000564701133626865910626)      // interestRate     5% per year
        );

         feed.file("riskGroup",
            1,                                      // riskGroup:       0
            8*10**26,                               // thresholdRatio   80%
            7*10**26,                               // ceilingRatio     70%
            ONE                                     // interestRate     1.0
        );
        feed.file("riskGroup",
            2,                                      // riskGroup:       0
            8*10**26,                               // thresholdRatio   90%
            8*10**26,                               // ceilingRatio     80%
            uint(1000000003593629043335673583)      // interestRate     12% per year
        );
    }

    function testNFTValues() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint value = 100 ether;
        feed.update(nftID, value);

        uint loan = 1;
        shelf.setReturn("shelf", address(1), 1);

        assertEq(feed.nftValues(nftID), 100 ether);
        assertEq(feed.threshold(loan), 80 ether);
        assertEq(feed.ceiling(loan), 60 ether);
    }

    function testCreditLineCeilingOutstandingDebt() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint riskGroup = 1;
        uint value = 100 ether;
        uint loan = 1;
        uint debt = 40 ether;
        uint maxCeiling = 70 ether;
        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        pile.incDebt(loan, debt);
        assertEq(feed.ceiling(loan), safeSub(maxCeiling, debt));
    }

    function testCreditLineCeilingOutstandingDebtBiggerCeiling() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint riskGroup = 1;
        uint loan = 1;
        uint value = 100 ether;
        uint debt = 71 ether;
        uint maxCeiling = 70 ether;
        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);
        pile.incDebt(loan, debt);
        assertEq(feed.ceiling(loan), 0);
    }

    function testAddRiskGroup() public {
        uint riskGroup = 4;
        uint thresholdRatio = 8*10**26;
        uint ceilingRatio =  8*10**26; 
        uint interestRate =  uint(1000000003593629043335673583);

        feed.file("riskGroup",
            riskGroup,                                  
            thresholdRatio,                              
            ceilingRatio,
            interestRate                              
        );
        (uint pie, uint chi, uint ratePerSecond, uint lastUpdate, uint fixedRate) = pile.rates(riskGroup);

         // check nft value set correctly
        assertEq(feed.thresholdRatio(riskGroup), thresholdRatio);
        // check threshold computed correctly
        assertEq(feed.ceilingRatio(riskGroup), ceilingRatio);
         // check interestrate set correctly
        assertEq(ratePerSecond, interestRate);
    }

    function testFailAddRiskGroupNoPermissions() public {
        feed.deny(address(this)); // revoke admin permissions
        feed.file("riskGroup",
            2,                                      // riskGroup:       0
            8*10**26,                               // thresholdRatio   90%
            8*10**26,                               // ceilingRatio     80%
            uint(1000000003593629043335673583)      // interestRate     12% per year
        );
    }

    function testUpdateRiskGroupLoanHasNoDebt() public {
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

    function testUpdateRiskGroupAndValueLoanHasDebt() public {
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
        // assert all values were set correctly
        assertLoanValuesSetCorrectly(nftID, value, loan, risk, true);
    }

    function testFailUpdateRiskGroupNoPermissions() public {
        feed.deny(address(this)); // revoke admin permissions

        uint risk = 1;
        bytes32 nftID = feed.nftID(address(1), 1);
        uint loan = 1;
        uint value = 100 ether;
        shelf.setReturn("shelf", address(1), 1);
        shelf.setReturn("nftlookup", loan);
        pile.setReturn("pie", 100);

        // set value and risk group of nft
        feed.update(nftID, value, risk);
    }

    function testBorrowEvent() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint value = 100 ether;
        uint risk = 0;

        uint loan = 1;
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
        uint riskGroup = 1;
        uint value = 100 ether;
        uint loan = 1;
        uint debt = 40 ether;
        uint maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);

        feed.borrow(loan, maxCeiling);
    }
    
    function testFailBorrowAmountTooHigh() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint riskGroup = 1;
        uint value = 100 ether;
        uint loan = 1;
        uint debt = 40 ether;
        uint maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), safeAdd(maxCeiling, 1 ether));

        feed.deny(address(this)); // revoke admin permissions
        feed.borrow(loan, maxCeiling);
    }

    function testFailBorrowNoPermission() public {
        bytes32 nftID = feed.nftID(address(1), 1);
        uint riskGroup = 1;
        uint value = 100 ether;
        uint loan = 1;
        uint debt = 40 ether;
        uint maxCeiling = 70 ether;

        feed.update(nftID, value, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        assertEq(feed.ceiling(loan), maxCeiling);

        feed.deny(address(this)); // revoke admin permissions
        feed.borrow(loan, maxCeiling);
    }

     function testWriteOff() public {
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

        feed.writeOff(loan);
        assertEq(pile.values_uint("changeRate_loan"), loan);
        assertEq(pile.values_uint("changeRate_rate"), feed.WRITEOFF_RATE_GROUP());
    }

    function testFailWriteOffNoPermissions() public {
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

        feed.deny(address(this)); // revoke admin permissions
        feed.writeOff(loan);
    }


    // function currentNAV() public view returns(uint) {
    //     uint totalDebt;
    //     // calculate total debt
    //     for (uint loanId = 1; loanId < shelf.loanCount(); loanId++) {
    //         totalDebt = safeAdd(totalDebt, pile.debt(loanId));
    //     }

    //     // substract writtenoff loans -> all writtenOff loans are moved to writeOffRateGroup
    //     totalDebt = safeSub(totalDebt, pile.rateDebt(WRITEOFF_RATE_GROUP));
    //     return totalDebt;
    // }

    function testCalcNav() public {
        bytes32 tokenId1 = feed.nftID(address(1), 1);
        bytes32 tokenId2 = feed.nftID(address(1), 2);
        bytes32 tokenId3 = feed.nftID(address(1), 3);
        uint value1 = 100;
        uint value2 = 1000;
        uint value3 = 10000;
        uint loan1 = 1;
        uint loan2 = 2;
        uint loan3 = 3;
        uint riskGroup = 1;
    
        feed.update(tokenId1, value1, riskGroup);
        feed.update(tokenId2, value2, riskGroup);
        feed.update(tokenId3, value3, riskGroup);

        shelf.setReturn("shelf", address(1), 1);
        feed.borrow(loan1, feed.ceiling(loan1));
        pile.incDebt(loan1, feed.ceiling(loan1)); 
        shelf.setReturn("shelf", address(1), 2);
        feed.borrow(loan2, feed.ceiling(loan2));
        pile.incDebt(loan2,feed.ceiling(loan2)); 
        shelf.setReturn("shelf", address(1), 3);
        feed.borrow(loan3, feed.ceiling(loan3));
        pile.incDebt(loan3, feed.ceiling(loan3)); 

        shelf.setReturn("loanCount", 4);
        uint currentNav = feed.currentNAV();
        assertEq(currentNav, safeAdd(safeAdd(70, 700), 7000));
    }

    // assertions
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
}


