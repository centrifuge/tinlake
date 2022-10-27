// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/math.sol";

import "../simple/token.sol";
import "src/lender/reserve.sol";
import "./mock/assessor.sol";
import "./mock/clerk.sol";

interface ReserveLike {
    function hardDeposit(uint currencyAmount) external;
    function hardPayout(uint currencyAmount) external;
}

contract LendingAdapterMock is ClerkMock {
    ReserveLike reserve;
    ERC20Like currency;

    constructor(address currency_, address reserve_) {
        reserve = ReserveLike(reserve_);
        currency = ERC20Like(currency_);
    }

    function draw(uint amount) public {
        currency.mint(address(this), amount);
        currency.approve(address(reserve), amount);
        reserve.hardDeposit(amount);
    }

    function wipe(uint amount) public {
        reserve.hardPayout(amount);
    }
}

contract ReserveTest is DSTest, Math {
    SimpleToken currency;
    Reserve reserve;
    AssessorMock assessor;

    LendingAdapterMock lending;

    address reserve_;
    address currency_;
    address assessor_;

    address self;

    function setUp() public {
        currency = new SimpleToken("CUR", "Currency");
        assessor = new AssessorMock();

        reserve = new Reserve(address(currency));
        reserve_ = address(reserve);
        currency_ = address(currency);
        assessor_ = address(assessor);
        self = address(this);
        currency.approve(reserve_, type(uint).max);
    }

    function setUpLendingAdapter() public {
        lending = new LendingAdapterMock(currency_, reserve_);
        reserve.depend("lending", address(lending));
        reserve.rely(address(lending));
        lending.setReturn("activated", true);
    }

    function fundReserve(uint amount) public {
        currency.mint(self, amount);
        currency.approve(reserve_, amount);
        reserve.deposit(amount);
    }

    function testFullLoanPayout() public {
        uint borrowAmount = 100 ether;
        // fund reserve with exact borrowAmount
        fundReserve(borrowAmount);

        uint reserveBalance = currency.balanceOf(reserve_);
        uint selfBalance = currency.balanceOf(self);

          // set maxCurrencyAvailable allowance to exact borrowAmount
        reserve.file("currencyAvailable", borrowAmount);
        uint currencyAvailable = reserve.currencyAvailable();

        reserve.payoutForLoans(currencyAvailable);

        // assert currency was transferred from reserve
        assertEq(currency.balanceOf(reserve_), safeSub(reserveBalance, borrowAmount));
        assertEq(currency.balanceOf(self), safeAdd(selfBalance, borrowAmount));
        assertEq(reserve.currencyAvailable(), safeSub(currencyAvailable, borrowAmount));
    }

    function testPartialPayout() public {
        uint borrowAmount = 100 ether;
        bool requestWant = true;
        // fund reserve with twice as much currency then borrowAmount
        fundReserve(safeMul(borrowAmount, 2));

        uint reserveBalance = currency.balanceOf(reserve_);
        uint selfBalance = currency.balanceOf(self);

        // set maxCurrencyAvailable allowance to twice as much as borrowAmount
        reserve.file("currencyAvailable",  safeMul(borrowAmount, 2));
        uint currencyAvailable = reserve.currencyAvailable();

        reserve.payoutForLoans(borrowAmount);

        // assert currency was transferred from reserve
        assertEq(currency.balanceOf(reserve_), safeSub(reserveBalance, borrowAmount));
        assertEq(currency.balanceOf(self), safeAdd(selfBalance, borrowAmount));
        assertEq(reserve.currencyAvailable(), safeSub(currencyAvailable, borrowAmount));
    }

    function testReserveBalanceRepay() public {
        uint repayAmount = 100 ether;
        bool requestWant = false;
        // fund test with enough currency
        currency.mint(self, repayAmount);

        uint reserveBalance = currency.balanceOf(reserve_);
        uint selfBalance = currency.balanceOf(self);
        uint currencyAvailable = reserve.currencyAvailable();

        //simulate shelf behaviour
        reserve.deposit(repayAmount);

        // assert currency was transferred to reserve
        assertEq(currency.balanceOf(reserve_), safeAdd(reserveBalance, repayAmount));
        assertEq(currency.balanceOf(self), safeSub(selfBalance, repayAmount));
        assertEq(reserve.currencyAvailable(), currencyAvailable);
    }

    function testFailBalancePoolInactive() public {
        uint borrowAmount = 100 ether;
        bool requestWant = true;
        // fund reserve with enough currency
        fundReserve(200 ether);
        // set max available currency
        reserve.file("currencyAvailable", 200 ether);
        // deactivate pool
        reserve.file("currencyAvailable", 0 ether);

        reserve.payoutForLoans(borrowAmount);
    }

    function testFailBalanceBorrowAmountTooHigh() public {
        uint borrowAmount = 100 ether;
        fundReserve(borrowAmount*2);

        // set max available currency
        reserve.file("currencyAvailable", borrowAmount);
        reserve.payoutForLoans(borrowAmount+1);
    }

    function testFailBalanceReserveUnderfunded() public {
        uint borrowAmount = 100 ether;
        // fund reserve with amount smaller than borrowAmount
        fundReserve(borrowAmount-1);

        // set max available currency to borrowAmount
        reserve.file("currencyAvailable", borrowAmount);
        reserve.payoutForLoans(borrowAmount);
    }

    function testDepositPayout() public {
        uint amount = 100 ether;
        currency.mint(self, amount);
        assertEq(reserve.totalBalance(), 0);
        currency.approve(reserve_, amount);
        reserve.deposit(amount);
        assertEq(reserve.totalBalance(), amount);
        assertEq(currency.balanceOf(reserve_), amount);

        amount = 60 ether;
        reserve.payout(amount);
        assertEq(reserve.totalBalance(), 40 ether);
        assertEq(currency.balanceOf(reserve_), 40 ether);
        assertEq(currency.balanceOf(self), 60 ether);
    }

    function testDrawFromZeroBalance() public {
        setUpLendingAdapter();
        uint remainingCredit = 100 ether;
        lending.setReturn("remainingCredit", remainingCredit);
        uint amount = 10 ether;
        reserve.payout(amount);
        assertEq(currency.balanceOf(self), amount);
    }

    function testAdditionalDraw() public {
        setUpLendingAdapter();
        uint amount = 100 ether;
        fundReserve(amount);
        uint remainingCredit = 100 ether;
        lending.setReturn("remainingCredit", remainingCredit);
        uint payoutAmount = 150 ether;
        reserve.payout(payoutAmount);
        assertEq(currency.balanceOf(self), payoutAmount);
    }

    function testAdditionalDrawMax() public {
        setUpLendingAdapter();
        uint amount = 100 ether;
        fundReserve(amount);

        uint remainingCredit = 100 ether;
        lending.setReturn("remainingCredit", remainingCredit);

        uint payoutAmount = 200 ether;
        reserve.payout(payoutAmount);
        assertEq(currency.balanceOf(self), payoutAmount);
    }
    function testFailDraw() public {
        setUpLendingAdapter();
        uint amount = 100 ether;
        fundReserve(amount);

        uint remainingCredit = 100 ether;
        lending.setReturn("remainingCredit", remainingCredit);

        uint payoutAmount = 201 ether;
        reserve.payout(payoutAmount);
        assertEq(currency.balanceOf(self), payoutAmount);
    }

    function testFailDrawFromZeroBalance() public {
        setUpLendingAdapter();

        uint remainingCredit = 100 ether;
        lending.setReturn("remainingCredit", remainingCredit);

        uint payoutAmount = 101 ether;
        reserve.payout(payoutAmount);
        assertEq(currency.balanceOf(self), payoutAmount);
    }

    function testWipe() public {
        setUpLendingAdapter();
        uint debt = 70 ether;
        lending.setReturn("debt", debt);

        uint amount = 100 ether;
        fundReserve(amount);
        assertEq(currency.balanceOf(reserve_), amount-debt);
    }

    function testWipeHighDebt() public {
        setUpLendingAdapter();
        uint debt = 700 ether;
        lending.setReturn("debt", debt);

        uint amount = 100 ether;
        fundReserve(amount);
        assertEq(currency.balanceOf(reserve_), 0);
        assertEq(currency.balanceOf(address(lending)), amount);
    }

    function testNoWipeZeroDebt() public {
        setUpLendingAdapter();
        uint debt = 0;
        lending.setReturn("debt", debt);
        uint amount = 100 ether;
        fundReserve(amount);
        assertEq(currency.balanceOf(reserve_), amount);
    }

    function testTotalReserveAvailable() public {
        uint amount = 100 ether;
        fundReserve(amount);

        assertEq(reserve.totalBalanceAvailable(), amount);

        setUpLendingAdapter();
        uint remainingCredit = 50 ether;
        lending.setReturn("remainingCredit", remainingCredit);
        assertEq(reserve.totalBalanceAvailable(), amount+remainingCredit);
    }

}
