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


contract LenderSystemTest is TestSuite, Interest {
    function setUp() public {
        // setup hevm
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        bool mkrAdapter = true;
        deployContracts(mkrAdapter);
        createTestUsers();

        nftFeed_ = NFTFeedLike(address(nftFeed));

        root.relyContract(address(clerk), address(this));

    }

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

    function testSimpleRaise() public {
        _setupRunningPool();
        uint preReserve = reserve.totalBalance();
        uint nav = nftFeed.calcUpdateNAV();
        uint preSeniorBalance = assessor.seniorBalance();

        uint amountDAI = 1 ether;

        emit log_named_uint("pre-seniorAsset", (assessor.seniorDebt()+assessor.seniorBalance_())/ 1 ether );
        emit log_named_uint("pre-nav", nftFeed_.currentNAV()/ 1 ether );
        emit log_named_uint("pre-reserve", assessor.totalBalance()/ 1 ether );

        //clerk.raise(amountDAI);

    }
}
