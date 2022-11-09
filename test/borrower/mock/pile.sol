// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";

contract PileMock is Mock {
    function total() public view returns (uint256) {
        return values_return["total"];
    }

    // returns the total debt of a interest rate group
    function rateDebt(uint256) public view returns (uint256) {
        return values_return["rate_debt"];
    }

    function setRate(uint256 loan, uint256 rate) public {
        emit log_named_uint("setRate_loan", loan);
        emit log_named_uint("setRate_rate", rate);
        values_uint["setRate_loan"] = loan;
        values_uint["setRate_rate"] = rate;
        calls["setRate"]++;
    }

    function changeRate(uint256 loan, uint256 rate) public {
        values_uint["changeRate_loan"] = loan;
        values_uint["changeRate_rate"] = rate;
        setReturn("loanRates", rate);
        calls["changeRate"]++;
    }

    function debt(uint256) public view returns (uint256) {
        return values_return["debt_loan"];
    }

    function debt() public returns (uint256) {
        return call("debt");
    }

    function pie(uint256) public returns (uint256) {
        return call("pie");
    }

    function incDebt(uint256 loan, uint256 currencyAmount) public {
        values_uint["incDebt_loan"] = loan;
        values_uint["incDebt_currencyAmount"] = currencyAmount;
        calls["incDebt"]++;
    }

    function decDebt(uint256 loan, uint256 currencyAmount) public {
        values_uint["decDebt_loan"] = loan;
        values_uint["decDebt_currencyAmount"] = currencyAmount;
        calls["decDebt"]++;
    }

    function accrue(uint256 loan) public {
        values_uint["accrue_loan"] = loan;
        calls["accrue"]++;
    }

    function file(bytes32, uint256 rate, uint256 ratePerSecond) public {
        values_uint["file_rate"] = rate;
        values_uint["file_ratePerSecond"] = ratePerSecond;
        calls["file"]++;
    }

    function loanRates(uint256) public view returns (uint256) {
        return values_return["loanRates"];
    }

    function rates(uint256) public view returns (uint256, uint256, uint256, uint48, uint256) {
        return (
            values_return["rates_pie"],
            values_return["rates_chi"],
            values_return["rates_ratePerSecond"],
            0,
            values_return["rates_fixedRate"]
        );
    }
}
