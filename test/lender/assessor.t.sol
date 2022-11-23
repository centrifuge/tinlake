// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/math.sol";

import "src/lender/assessor.sol";
import "./mock/tranche.sol";
import "./mock/navFeed.sol";
import "./mock/reserve.sol";
import "./mock/clerk.sol";
import "../simple/token.sol";

interface Hevm {
    function warp(uint256) external;
}

contract AssessorTest is Test, Math {
    Hevm hevm;
    Assessor assessor;
    TrancheMock seniorTranche;
    TrancheMock juniorTranche;
    NAVFeedMock navFeed;
    ReserveMock reserveMock;
    SimpleToken currency;
    ClerkMock clerk;

    address seniorTranche_;
    address juniorTranche_;
    address navFeed_;
    address reserveMock_;
    address clerk_;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
        currency = new SimpleToken("CUR", "Currency");

        seniorTranche = new TrancheMock();
        juniorTranche = new TrancheMock();

        seniorTranche_ = address(seniorTranche);
        juniorTranche_ = address(juniorTranche);

        navFeed = new NAVFeedMock();
        navFeed_ = address(navFeed);

        reserveMock = new ReserveMock(address(currency));
        reserveMock_ = address(reserveMock);

        clerk = new ClerkMock();
        clerk_ = address(clerk);

        assessor = new Assessor();
        assessor.depend("juniorTranche", juniorTranche_);
        assessor.depend("seniorTranche", seniorTranche_);
        assessor.depend("navFeed", navFeed_);
        assessor.depend("reserve", reserveMock_);
        assessor.depend("lending", clerk_);
    }

    function testCurrentNAV() public {
        navFeed.setReturn("calcUpdateNAV", 100 ether);
        assertEq(assessor.calcUpdateNAV(), 100 ether);
    }

    function testFileAssessor() public {
        uint256 maxReserve = 10000 ether;
        uint256 maxSeniorRatio = 80 * 10 ** 25;
        uint256 minSeniorRatio = 75 * 10 ** 25;
        uint256 seniorInterestRate = 1000000593415115246806684338; // 5% per day

        assessor.file("seniorInterestRate", seniorInterestRate);
        assertEq(assessor.seniorInterestRate(), seniorInterestRate);

        assessor.file("maxReserve", maxReserve);
        assertEq(assessor.maxReserve(), maxReserve);

        assessor.file("maxSeniorRatio", maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);

        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testFailFileMinRatio() public {
        // min needs to be smaller than max
        uint256 minSeniorRatio = 75 * 10 ** 25;
        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testFailFileMaxRatio() public {
        // min needs to be smaller than max
        uint256 minSeniorRatio = 75 * 10 ** 25;
        uint256 maxSeniorRatio = 80 * 10 ** 25;

        assessor.file("maxSeniorRatio", maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);

        assessor.file("minSeniorRatio", minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);

        // should fail
        assessor.file("maxSeniorRatio", minSeniorRatio - 1);
    }

    function testChangeSeniorAsset() public {
        uint256 seniorSupply = 80 ether;
        uint256 seniorRedeem = 0;

        navFeed.setReturn("latestNAV", 10 ether);
        reserveMock.setReturn("balance", 90 ether);

        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 8 ether);
        assertEq(assessor.seniorBalance(), seniorSupply - 8 ether);
    }

    function testChangeSeniorAssetRatioExceedsONE() public {
        uint256 seniorSupply = 300 ether;
        uint256 seniorRedeem = 0;

        navFeed.setReturn("latestNAV", 200 ether);
        reserveMock.setReturn("balance", 0 ether);

        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);

        // assert seniorRatio does not exceed ONE
        assertEq(assessor.seniorRatio(), ONE);
    }

    function testChangeSeniorAssetOnlySenior() public {
        uint256 seniorSupply = 100 ether;
        uint256 seniorRedeem = 0;

        navFeed.setReturn("latestNAV", 10 ether);
        reserveMock.setReturn("balance", 90 ether);

        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 10 ether);
        assertEq(assessor.seniorBalance(), seniorSupply - 10 ether);
    }

    function testChangeSeniorAssetNoNAV() public {
        uint256 seniorSupply = 100 ether;
        uint256 seniorRedeem = 0;

        navFeed.setReturn("latestNAV", 0);
        reserveMock.setReturn("balance", 120 ether);

        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 0);
        assertEq(assessor.seniorBalance(), seniorSupply);
    }

    function testChangeSeniorAssetFullSenior() public {
        uint256 seniorSupply = 100 ether;
        uint256 seniorRedeem = 0;

        navFeed.setReturn("latestNAV", 10 ether);
        reserveMock.setReturn("balance", 50 ether);

        assessor.changeSeniorAsset(seniorSupply, seniorRedeem);
        assertEq(assessor.seniorDebt(), 10 ether);
        assertEq(assessor.seniorBalance(), 90 ether);
    }

    function testSeniorInterest() public {
        // 5% per day
        uint256 interestRate = uint256(1000000564701133626865910626);
        assessor.file("seniorInterestRate", interestRate);

        navFeed.setReturn("latestNAV", 200 ether);
        reserveMock.setReturn("balance", 200 ether);

        uint256 seniorSupply = 200 ether;

        // seniorRatio 50%
        assessor.changeSeniorAsset(seniorSupply, 0);
        assertEq(assessor.seniorDebt(), 100 ether);
        assertEq(assessor.seniorBalance(), 100 ether);

        hevm.warp(block.timestamp + 1 days);
        assertEq(assessor.seniorDebt(), 105 ether);
        assessor.dripSeniorDebt();
        assertEq(assessor.seniorDebt(), 105 ether);

        hevm.warp(block.timestamp + 1 days);
        assessor.dripSeniorDebt();
        assertEq(assessor.seniorDebt(), 110.25 ether);
    }

    function testFirstDrip() public {
        uint256 interestRate = uint256(1000000564701133626865910626);
        assessor.file("seniorInterestRate", interestRate);

        hevm.warp(block.timestamp + 1 days);
        assessor.dripSeniorDebt();

        // first drip should already update lastUpdateSeniorInterest, even if seniorDebt_ is unset,
        // to prevent it being applied twice.
        assertEq(assessor.lastUpdateSeniorInterest(), block.timestamp);
    }

    function testCalcSeniorTokenPriceWithSupplyRoundingError() public {
        uint256 nav = 10 ether;
        navFeed.setReturn("latestNAV", nav);
        uint256 seniorTokenSupply = 2; // set value in range of supply rounding tolearnce
        reserveMock.setReturn("balance", 100 ether);
        seniorTranche.setReturn("tokenSupply", seniorTokenSupply);

        uint256 seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 123123 ether);
        // assert senior token price is ONE
        assertEq(seniorTokenPrice, ONE);
    }

    function testCalcSeniorTokenPrice() public {
        uint256 nav = 10 ether;
        navFeed.setReturn("latestNAV", nav);
        uint256 seniorSupply = 80 ether;
        reserveMock.setReturn("balance", 100 ether);

        assessor.changeSeniorAsset(seniorSupply, 0);
        seniorTranche.setReturn("tokenSupply", 40 ether);

        uint256 seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 123123 ether);
        // seniorAsset: 80 ether, tokenSupply: 40 ether
        assertEq(seniorTokenPrice, 2 * 10 ** 27);

        reserveMock.setReturn("balance", 30 ether);
        seniorTokenPrice = assessor.calcSeniorTokenPrice(nav, 123123 ether);
        // seniorAsset: 40 ether, tokenSupply: 40 ether
        assertEq(seniorTokenPrice, 1 * 10 ** 27);
    }

    function testCalcJuniorTokenPrice() public {
        uint256 nav = 10 ether;
        navFeed.setReturn("latestNAV", nav);
        uint256 seniorSupply = 80 ether;
        reserveMock.setReturn("balance", 90 ether);

        assessor.changeSeniorAsset(seniorSupply, 0);
        juniorTranche.setReturn("tokenSupply", 20 ether);
        uint256 juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, 123123 ether);

        assertEq(juniorTokenPrice, 1 * 10 ** 27);

        clerk.setReturn("juniorStake", 20 ether);
        juniorTokenPrice = assessor.calcJuniorTokenPrice(nav, 123123 ether);

        assertEq(juniorTokenPrice, 2 * 10 ** 27);
    }

    function testCalcTokenPrices() public {
        (uint256 juniorPrice, uint256 seniorPrice) = assessor.calcTokenPrices(0, 0);
        assertEq(juniorPrice, ONE);
        assertEq(seniorPrice, ONE);

        uint256 reserve = 300 ether;
        uint256 nav = 200 ether;

        navFeed.setReturn("latestNAV", 200 ether);
        reserveMock.setReturn("balance", 200 ether);

        uint256 seniorSupply = 200 ether;

        // seniorRatio 50%
        assessor.changeSeniorAsset(seniorSupply, 0);
        assertEq(assessor.seniorDebt(), 100 ether);
        assertEq(assessor.seniorBalance(), 100 ether);

        reserve = 300 ether;
        nav = 200 ether;

        juniorTranche.setReturn("tokenSupply", 100 ether);
        // NAV + Reserve  = 500 ether
        // seniorAsset = 200 ether
        // juniorAsset = 300 ether

        // junior price: 3.0
        (juniorPrice, seniorPrice) = assessor.calcTokenPrices(nav, reserve);
        assertEq(juniorPrice, 3 * 10 ** 27);
        assertEq(seniorPrice, 1 * 10 ** 27);
    }

    function testTotalBalance() public {
        uint256 totalBalance = 100 ether;
        reserveMock.setReturn("balance", totalBalance);
        assertEq(assessor.totalBalance(), totalBalance);
    }

    function testchangeBorrowAmountEpoch() public {
        uint256 amount = 100 ether;
        assertEq(reserveMock.values_uint("borrow_amount"), 0);
        assessor.changeBorrowAmountEpoch(amount);
        assertEq(reserveMock.values_uint("borrow_amount"), amount);
    }
}
