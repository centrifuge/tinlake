// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";
import "tinlake-math/interest.sol";

import "src/lender/adapters/mkr/simpleClerk.sol";
import "test/simple/token.sol";
import "test/lender/mock/assessor.sol";
import "./mock/mgr.sol";
import "./mock/vat.sol";
import "src/lender/definitions.sol";
import "test/system/assertions.sol";

contract AssessorMockWithDef is AssessorMock, Definitions {}

contract ClerkTest is Assertions, Interest {
    SimpleToken currency;
    SimpleToken collateral;
    AssessorMockWithDef assessor;

    ManagerMock mgr;
    VatMock vat;

    SimpleClerk clerk;

    function setUp() public {
        currency = new SimpleToken("DAI", "DAI");
        collateral = new SimpleToken("DROP", "DROP");
        assessor = new AssessorMockWithDef();
        mgr = new ManagerMock(address(currency), address(collateral));
        mgr.setIlk("DROP");
        vat = new VatMock();
        clerk = new SimpleClerk(address(mgr), address(assessor), address(collateral), address(currency), address(0));

        vat.setReturn("stabilityFeeIdx", ONE);
        mgr.setVat(address(vat));
        mgr.setBytes32Return("ilk", "DROP");
        // cdp not in soft liquidation
        mgr.setReturn("safe", true);
        // cdp not in hard liquidation
        mgr.setReturn("glad", true);
        // global settlement not triggere
        mgr.setReturn("live", true);
        // make clerk ward on mgr
        mgr.setOperator(address(clerk));
        assertEq(mgr.operator(), address(clerk));
    }

    function testBorrowSuccess(uint128 amountDROP, address user, uint16 seniorTokenPrice) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDROP != 0);
        assessor.setReturn("calcSeniorTokenPrice", seniorTokenPrice);

        // Set user as investor and mint them DROP
        clerk.relyInvestor(user);
        collateral.mint(user, amountDROP);

        // approve clerk to take DROP from user
        vm.prank(user);
        collateral.approve(address(clerk), amountDROP);

        // borrow currency via clerk
        vm.prank(user);
        clerk.borrow(amountDROP);
        uint256 amountDAI = mul(amountDROP, assessor.calcSeniorTokenPrice());
        assertEq(currency.balanceOf(user), amountDAI);
        assertEq(collateral.balanceOf(user), 0);
    }

    function testBorrowAsNonInvestorFails(uint256 amountDROP, address user) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDROP != 0);
        // Set user as investor and mint them DROP
        collateral.mint(user, amountDROP);

        // approve clerk to take DROP from user
        vm.prank(user);
        collateral.approve(address(clerk), amountDROP);

        // borrow currency via clerk
        vm.prank(user);
        vm.expectRevert("SimpleClerk/not-an-investor");
        clerk.borrow(amountDROP);
    }

    function testBorrowWithInsufficientFundsFails(uint256 amountDROP, address user) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDROP != 0);
        // Set user as investor
        clerk.relyInvestor(user);

        // approve clerk to take DROP from user
        vm.prank(user);
        collateral.approve(address(clerk), amountDROP);

        // borrow currency via clerk
        vm.prank(user);
        vm.expectRevert("cent/insufficient-balance");
        clerk.borrow(amountDROP);
    }

    function testBorrowWithoutClerkApprovalFails(uint256 amountDROP, address user) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDROP != 0);
        // Set user as investor and mint them DROP
        clerk.relyInvestor(user);
        collateral.mint(user, amountDROP);

        // borrow currency via clerk
        vm.prank(user);
        vm.expectRevert("cent/insufficient-allowance");
        clerk.borrow(amountDROP);
    }

    function testRepay(uint128 amountDAI, address user, uint16 seniorTokenPrice) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDAI != 0);
        vm.assume(seniorTokenPrice != 0);
        assessor.setReturn("calcSeniorTokenPrice", seniorTokenPrice);
        uint256 amountDROP = divup(mul(amountDAI, RAY), assessor.calcSeniorTokenPrice());
        vat.setReturn("tab", amountDAI);

        // fund mgr with collateral
        collateral.mint(address(mgr), amountDROP);

        // Set user as investor and mint them DROP
        clerk.relyInvestor(user);
        currency.mint(user, amountDAI);

        // approve clerk to take currency from user
        vm.prank(user);
        currency.approve(address(clerk), amountDAI);

        // repay currency via clerk
        vm.prank(user);
        clerk.repay(amountDAI);
        assertEq(currency.balanceOf(user), 0);
        assertEq(currency.balanceOf(address(clerk)), 0);
        assertEq(collateral.balanceOf(address(clerk)), 0);
        assertEq(collateral.balanceOf(address(mgr)), 0);
        assertEq(collateral.balanceOf(user), amountDROP);
    }

    function testRepayAsNonInvestorFails(uint128 amountDAI, address user, uint16 seniorTokenPrice) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDAI != 0);
        vm.assume(seniorTokenPrice != 0);
        assessor.setReturn("calcSeniorTokenPrice", seniorTokenPrice);
        uint256 amountDROP = divup(mul(amountDAI, RAY), assessor.calcSeniorTokenPrice());
        vat.setReturn("tab", amountDAI);

        // fund mgr with collateral
        collateral.mint(address(mgr), amountDROP);

        // mint user DROP without setting them as investor
        currency.mint(user, amountDAI);

        // approve clerk to take currency from user
        vm.prank(user);
        currency.approve(address(clerk), amountDAI);

        // repay currency via clerk
        vm.prank(user);
        vm.expectRevert("SimpleClerk/not-an-investor");
        clerk.repay(amountDAI);
    }

    function testRepayWithInsufficientFundsFails(uint128 amountDAI, address user, uint16 seniorTokenPrice) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDAI != 0);
        vm.assume(seniorTokenPrice != 0);
        assessor.setReturn("calcSeniorTokenPrice", seniorTokenPrice);
        uint256 amountDROP = divup(mul(amountDAI, RAY), assessor.calcSeniorTokenPrice());
        vat.setReturn("tab", amountDAI);

        // fund mgr with collateral
        collateral.mint(address(mgr), amountDROP);

        // Set user as investor
        clerk.relyInvestor(user);

        // approve clerk to take currency from user
        vm.prank(user);
        currency.approve(address(clerk), amountDAI);

        // repay currency via clerk
        vm.prank(user);
        vm.expectRevert("cent/insufficient-balance");
        clerk.repay(amountDAI);
    }

    function testRepayWithoutClerkApprovalFails(uint128 amountDAI, address user, uint16 seniorTokenPrice) public {
        vm.assume(user != address(clerk));
        vm.assume(amountDAI != 0);
        vm.assume(seniorTokenPrice != 0);
        assessor.setReturn("calcSeniorTokenPrice", seniorTokenPrice);
        uint256 amountDROP = divup(mul(amountDAI, RAY), assessor.calcSeniorTokenPrice());
        vat.setReturn("tab", amountDAI);

        // fund mgr with collateral
        collateral.mint(address(mgr), amountDROP);

        // Set user as investor and mint them DROP
        clerk.relyInvestor(user);
        currency.mint(user, amountDAI);

        // repay currency via clerk
        vm.prank(user);
        vm.expectRevert("cent/insufficient-allowance");
        clerk.repay(amountDAI);
    }

    function testRepayWithoutSufficientCollateralInMgrFails(uint128 amountDAI, address user, uint16 seniorTokenPrice)
        public
    {
        vm.assume(user != address(clerk));
        vm.assume(amountDAI != 0);
        vm.assume(seniorTokenPrice != 0);
        assessor.setReturn("calcSeniorTokenPrice", seniorTokenPrice);
        uint256 amountDROP = divup(mul(amountDAI, RAY), assessor.calcSeniorTokenPrice());
        vat.setReturn("tab", amountDAI);

        // Set user as investor and mint them DROP
        clerk.relyInvestor(user);
        currency.mint(user, amountDAI);

        // approve clerk to take currency from user
        vm.prank(user);
        currency.approve(address(clerk), amountDAI);

        // repay currency via clerk
        vm.prank(user);
        vm.expectRevert("cent/insufficient-balance");
        clerk.repay(amountDAI);
    }

    // --- Math ---
    uint256 constant RAY = 10 ** 27;

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(x, sub(y, 1)) / y;
    }
}
