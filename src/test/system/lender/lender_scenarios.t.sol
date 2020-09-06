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

import "../base_system.sol";
import {BaseTypes} from "../../../lender/test/coordinator-base.t.sol";

contract LenderSystemTest is BaseSystemTest, BaseTypes {
    Hevm public hevm;

    function setUp() public {
        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        baseSetup();
        createTestUsers(false);

        admin.whitelistInvestor(address(seniorOperator), seniorInvestor_);
        admin.whitelistInvestor(address(juniorOperator), juniorInvestor_);
        nftFeed_ = NFTFeedLike(address(nftFeed));

}

    function seniorSupply(uint currencyAmount) public {
        currency.mint(address(seniorInvestor), currencyAmount);
        seniorInvestor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = seniorTranche.users(seniorInvestor_);
        assertEq(supplyAmount, currencyAmount);
    }

    function juniorSupply(uint currencyAmount) public {
        currency.mint(address(juniorInvestor), currencyAmount);
        juniorInvestor.supplyOrder(currencyAmount);
        (,uint supplyAmount, ) = juniorTranche.users(juniorInvestor_);
        assertEq(supplyAmount, currencyAmount);
    }

    function closeEpoch(bool closeWithExecute) public {
        uint currentEpoch = coordinator.currentEpoch();
        uint lastEpochExecuted = coordinator.lastEpochExecuted();

        coordinator.closeEpoch();
        assertEq(coordinator.currentEpoch(), currentEpoch+1);
        if(closeWithExecute == true) {
            lastEpochExecuted++;
        }
        assertEq(coordinator.lastEpochExecuted(), lastEpochExecuted);
    }

    function testSupplyClose() public {
        uint seniorSupplyAmount = 82 ether;
        uint juniorSupplyAmount = 18 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(now + 1 days);

        closeEpoch(true);
    }

    function testLenderScenarioA() public {
        uint seniorSupplyAmount = 100000 ether;
        uint juniorSupplyAmount = 20 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        hevm.warp(now + 1 days);

        closeEpoch(false);
        assertTrue(coordinator.submissionPeriod() == true);

        ModelInput memory solution = ModelInput({
            seniorSupply : 82 ether,
            juniorSupply : 18 ether,
            seniorRedeem : 0 ether,
            juniorRedeem : 0 ether
            });

        int valid = submitSolution(address(coordinator), solution);
        assertEq(valid, coordinator.NEW_BEST());

        hevm.warp(now + 2 hours);

        coordinator.executeEpoch();
        assertEq(reserve.totalBalance(), 100 ether);

        seniorInvestor.disburse();
        juniorInvestor.disburse();
        assertEq(seniorToken.balanceOf(seniorInvestor_), 82 ether);
        assertEq(juniorToken.balanceOf(juniorInvestor_), 18 ether);

        // borrow loans
        uint nftPrice = 200 ether;
        uint borrowAmount = 100 ether;
        bool lenderFundingRequired = false;
        uint maturityDate = nftFeed.uniqueDayTimestamp(now) + 5 days;
        (uint loan, uint tokenId) = setupOngoingLoan(nftPrice, borrowAmount, lenderFundingRequired, maturityDate);

        assertEq(currency.balanceOf(address(borrower)), borrowAmount);


        uint nav = nftFeed.calcUpdateNAV();

        uint fv = nftFeed.futureValue(nftFeed.nftID(loan));
        // FV = 100 * 1.05^5 = 127.62815625
        assertEq(fv, 127.62815625 ether);

        // (FV/1.03^5) = 110.093;
        assertEq(nav, 110.093921369062927876 ether);

        // current senior ratio is 82%
        uint seniorSupply_ = 82 ether;
        assertEq(assessor.seniorDebt(), seniorSupply_);

        uint seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 0);
        assertEq(seniorTokenPrice, ONE);
        assertEq(assessor.seniorRatio(), fixed18To27(0.82 ether));

        // time impact on token senior token price
        hevm.warp(now + 1 days);

        // additional senior debt increase for one day
        // 82 * 1.02 = 83.64
        assertEq(assessor.seniorDebt(), 83.64 ether, TWO_DECIMAL_PRECISION);


        nav = nftFeed.calcUpdateNAV();

        //(FV/1.03^4) = 127.62815625 /(1.03^4) = 113.395963777
        assertEq(nav, 113.39 ether, TWO_DECIMAL_PRECISION);

        // should be 83.64/82 = 83.64/82= 1.02
        seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 0);
        assertEq(seniorTokenPrice, fixed18To27(1.02 ether), FIXED27_FOUR_DECIMAL_PRECISION);


        // seniorRatio should be still the old one
        assertEq(assessor.seniorRatio(), fixed18To27(0.82 ether));

        // new orders
        // first investors need to disburse

        seniorSupplyAmount = 80 ether;
        juniorSupplyAmount = 20 ether;
        seniorSupply(seniorSupplyAmount);
        juniorSupply(juniorSupplyAmount);

        // minimum epoch should be already reached
        coordinator.closeEpoch();
        // epoch should be executed
        assertTrue(coordinator.submissionPeriod() == false);

        // todo continue

        // seniorAsset = 80 + 83.64 = 163.64
        // assertEq(assessor.seniorBalance(), 80 ether);
        // assertEq(assessor.seniorDebt(), 83.64 ether, TWO_DECIMAL_PRECISION);

        // juniorAsset = (nav + reserve) - seniorAsset
        // juniorAsset = 113.39 + 100 - 163.64 = 49.75
        // seniorRatio = 163.64/200 = 0.8182
       //  assertEq(assessor.seniorRatio(), fixed18To27(0.8182 ether));

    }
}

