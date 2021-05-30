// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;


import "tinlake-math/interest.sol";
import {BaseTypes} from "../../../lender/test/coordinator-base.t.sol";

import "../test_suite.sol";

contract UnderwriterSystemTest is TestSuite, Interest {

    function setUp() public {
        // setup hevm
        hevm = Hevm(HEVM_ADDRESS);

        baseSetup();
        createTestUsers();
        nftFeed_ = NFTFeedLike(address(nftFeed));
    }

    function testFinanceUnstakedLoan() public {
        // invest
        uint seniorSupplyAmount = 700 ether;
        uint juniorSupplyAmount = 300 ether;

        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(block.timestamp + 1 days);

        closeEpoch(true);
        assertEqTol(reserve.totalBalance(), seniorSupplyAmount + juniorSupplyAmount, " firstLoan#1");

        // attempt to open loan
        // uint nftPrice = 200 ether;
        // uint borrowAmount = 100 ether;
        // uint maturity = 5 days;
        // setupOngoingLoan(nftPrice, borrowAmount, block.timestamp + maturity);
    }
 }
