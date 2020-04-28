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

import "ds-test/test.sol";

import "../../test/mock/tranche.sol";
import "../../test/mock/assessor.sol";
import "../../test/mock/distributor.sol";
import "tinlake-math/math.sol";

import "./../operator/proportional.sol";
import "./investor.t.sol";


contract ProportionalOperatorTest is DSTest, Math {
    uint256 constant ONE = 10 ** 27;

    AssessorMock assessor;
    TrancheMock tranche;
    DistributorMock distributor;
    ProportionalOperator operator;
    address operator_;

    Investor investorA;
    Investor investorB;

    function setUp() public {
        assessor =  new AssessorMock();
        assessor.setReturn("tokenPrice", ONE);
        assessor.setReturn("supplyApprove", true);
        assessor.setReturn("redeemApprove", true);

        tranche = new TrancheMock();

        investorA = new Investor();
        investorB = new Investor();

        distributor = new DistributorMock();
        operator = new ProportionalOperator(address(tranche), address(assessor), address(distributor));
        operator_ = address(operator);

        operator.depend("tranche", address(tranche));
}

    // basic tests
    function testApproveSupply() public {
        uint amount = 100 ether;
        operator.approve(address(investorA), amount);
        investorA.doSupply(operator_, amount);
        assertEq(tranche.calls("supply"), 1);
        assertEq(tranche.values_uint("supply_currencyAmount"), amount);
    }

    function testUpdateReturn() public {
        uint currencyReturned = 110 ether;
        uint principalReturned = 100 ether;
        operator.updateReturned(currencyReturned, principalReturned);
        assertEq(operator.totalCurrencyReturned(), currencyReturned);
        assertEq(operator.totalPrincipalReturned(), principalReturned);

        operator.updateReturned(currencyReturned, principalReturned);
        assertEq(operator.totalCurrencyReturned(), currencyReturned*2);
        assertEq(operator.totalPrincipalReturned(), principalReturned*2);
    }

    function testFailSupplyTooMuch() public {
        uint amount = 100 ether;
        operator.approve(address(investorA), amount);
        investorA.doSupply(operator_, amount + 1);
    }

    function supplyInvestor(Investor investor, uint amount) internal {
        operator.approve(address(investor), amount);
        investor.doSupply(operator_, amount );
    }

    function testMaxRedeemToken() public {
        supplyInvestor(investorA, 100 ether);
        supplyInvestor(investorB, 100 ether);
        assertEq(operator.calcMaxRedeemToken(address(investorA)), 0);

        // start redeem
        uint totalSupply = 200 ether;
        tranche.setReturn("tokenSupply", totalSupply);
        operator.file("supplyAllowed", false);

        // simulate loan repayments
        uint currencyReturned = 105 ether;
        uint principalReturned = 100 ether;
        operator.updateReturned(currencyReturned, principalReturned);

        // check maxRedeemToken
        assertEq(operator.calcMaxRedeemToken(address(investorA)), 50 ether);
    }

    function setUpInvestors(uint amountA, uint amountB) public returns(uint) {
        supplyInvestor(investorA, 100 ether);
        supplyInvestor(investorB, 100 ether);

        uint totalSupply = amountA + amountB;
        tranche.setReturn("tokenSupply", totalSupply);

        // start redeem
        operator.file("supplyAllowed", false);

        return totalSupply;
    }

    function testSimplePropRedeem() public {
        uint amountInvestorA = 100 ether;
        uint amountInvestorB = 100 ether;
        setUpInvestors(amountInvestorA, amountInvestorB);

        // simulate return loan 1 (50% of the principal)
        uint currencyReturned = 105 ether;
        uint principalReturned = 100 ether;
        operator.updateReturned(currencyReturned, principalReturned);


        // max redeem should be 50 ether of first investor
        uint tokenAmount = 50 ether;
        uint expectedCurrencyAmount = 52.5 ether;
        assertEq(operator.calcMaxRedeemToken(address(investorA)), tokenAmount);

        investorA.doRedeem(address(operator), tokenAmount);
        assertEq(tranche.values_uint("redeem_currencyAmount"), expectedCurrencyAmount);
        assertEq(tranche.values_uint("redeem_tokenAmount"), tokenAmount);

        // simulate return loan 2 (50% of the principal)
        currencyReturned = 105 ether;
        principalReturned = 100 ether;
        operator.updateReturned(currencyReturned, principalReturned);

        // investor A
        assertEq(operator.calcMaxRedeemToken(address(investorA)), tokenAmount);
        investorA.doRedeem(address(operator), tokenAmount);
        assertEq(tranche.values_uint("redeem_currencyAmount"), expectedCurrencyAmount);
        assertEq(tranche.values_uint("redeem_tokenAmount"), tokenAmount);

        // investor B only redeems once after loan 2
        tokenAmount = 100 ether;
        expectedCurrencyAmount = 105 ether;
        assertEq(operator.calcMaxRedeemToken(address(investorB)), tokenAmount);
        investorB.doRedeem(address(operator), tokenAmount);
        assertEq(tranche.values_uint("redeem_currencyAmount"), expectedCurrencyAmount);
        assertEq(tranche.values_uint("redeem_tokenAmount"), tokenAmount);
    }

    function redeem(Investor investor, uint maxToken, uint tokenAmount, uint expectedCurrencyAmount) public {
        // do redeem for investor
        assertEq(operator.calcMaxRedeemToken(address(investor)), maxToken);
        investor.doRedeem(address(operator), tokenAmount);
        assertEq(tranche.values_uint("redeem_currencyAmount"), expectedCurrencyAmount);
        assertEq(tranche.values_uint("redeem_tokenAmount"), tokenAmount);
    }

    uint constant loanAmount = 3;
    function testScenarioRedeemA() public {
        /*

        Scenario Description:
                    currencyAmount   tokenAmount
        Investor A: $100                 100
        Investor B: $100                 100
        Total:      $200                 200

        Loans

        +---------+-----------+-----------+-------------------+-------------+
        | Loan    | Principal | Repayment | % Principal       | Desc        |
        +---------+-----------+-----------+-------------------+-------------+
        | Loan 1  | 90        | 101       | 0.45              | profit: 11  |
        +---------+-----------+-----------+-------------------+-------------+
        | Loan 2  | 40        | 44        | 0.2               | profit: 4   |
        +---------+-----------+-----------+-------------------+-------------+
        | Loan 3  | 70        | 65        | 0.35              | loss: 5     |
        +---------+-----------+-----------+-------------------+-------------+

        Total Profit: 10
        Investor A: 105
        Investor B: 105

        Investor A
	                    max 	tokenAmount     currencyAmount
        After Loan 1	45.00	    30.00	        $33.67
        After loan 2 	35.00	    15.00	        $16.64
        After Loan 3	55.00	    55.00	    	$54.69
        Total:                                      $105


        Investor B
                            max 	tokenAmount     currencyAmount
        After Loan 3    	100.00	    100.00	        $105
        */

        uint[loanAmount] memory principalReturned = [90 ether , uint(40 ether), uint(70 ether)];
        uint[loanAmount] memory currencyReturned = [101 ether, uint(44 ether), uint(65 ether)];

        // investor A
        uint[loanAmount] memory maxToken = [45 ether ,uint(35000000000000000000), uint(55000000000000000000)];
        uint[loanAmount] memory tokenAmount = [30 ether ,uint(15 ether), uint(55000000000000000000)];
        uint[loanAmount] memory expectedCurrency = [33666666666666666666, uint(16642857142857142857), uint(54690476190476190476)];

        uint amountInvestorA = 100 ether;
        uint amountInvestorB = 100 ether;
        setUpInvestors(amountInvestorA, amountInvestorB);

        // investor A
        uint totalInvestorA = 0;
        for(uint i = 0; i < loanAmount; i++) {
            // simulate loan repayment
            operator.updateReturned(currencyReturned[i], principalReturned[i]);
            redeem(investorA, maxToken[i], tokenAmount[i], expectedCurrency[i]);
            totalInvestorA += expectedCurrency[i];
        }

        // investor B only redeems once after loan 3
        uint maxTokenB = 100 ether;
        uint tokenAmountB = 100 ether;
        uint expectedReturnB = 105 ether;
        redeem(investorB, maxTokenB, tokenAmountB, expectedReturnB);

        // both investors should have the same amount of tokens in the end
        // 1 wei tolerance
        assertTrue(expectedReturnB-totalInvestorA <= 1);
    }

    function testNotSupplyAll() public {
        uint max = 100 ether;
        uint amountA = 100 ether;
        uint amountB = 50 ether;
        operator.approve(address(investorA), max);
        operator.approve(address(investorB), max);

        investorA.doSupply(operator_, amountA);
        investorB.doSupply(operator_, amountB);

        uint totalSupply = amountA + amountB;
        tranche.setReturn("tokenSupply", totalSupply);

        // start redeem
        operator.file("supplyAllowed", false);


        // simulate return loan 1 (66 % of the principal)
        uint currencyReturned = 110 ether;
        uint principalReturned = 100 ether;
        operator.updateReturned(currencyReturned, principalReturned);


        assertEq(operator.calcMaxRedeemToken(address(investorA)), 66666666666666666666);
        assertEq(operator.calcMaxRedeemToken(address(investorB)), 33333333333333333333);

    }
}


