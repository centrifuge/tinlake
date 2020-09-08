pragma solidity >=0.5.15 <0.6.0;

import "../../../test/mock/mock.sol";
import "ds-test/test.sol";

contract PileMock is Mock {
    function total() public view returns(uint) {
        return values_return["total"];
    }

    function setRate(uint loan, uint rate) public {
        values_uint["setRate_loan"] = loan;
        values_uint["setRate_rate"] = rate;
        calls["setRate"]++;
    }

    function changeRate(uint loan, uint rate) public {
        values_uint["changeRate_loan"] = loan;
        values_uint["changeRate_rate"] = rate;
        calls["changeRate"]++;

    }

    function debt(uint loan) public returns(uint) {
        // name = "debt_loan" because of two debt funcs
        values_uint["debt_loan_loan"] = loan;
        calls["debt_loan"]++;
        return values_return["debt_loan"];
    }

    function debt() public returns(uint) {
        return call("debt");
    }

    function pie(uint) public returns(uint) {
        return call("pie");
    }

    function incDebt(uint loan, uint currencyAmount) public {
        values_uint["incDebt_loan"] = loan;
        values_uint["incDebt_currencyAmount"] = currencyAmount;
        calls["incDebt"]++;
    }

    function decDebt(uint loan, uint currencyAmount) public {
        values_uint["decDebt_loan"] = loan;
        values_uint["decDebt_currencyAmount"] = currencyAmount;
        calls["decDebt"]++;
    }

    function accrue(uint loan) public {
        values_uint["accrue_loan"] = loan;
        calls["accrue"]++;
    }

    function file(bytes32, uint rate, uint ratePerSecond) public {
        values_uint["file_rate"] = rate;
        values_uint["file_ratePerSecond"] = ratePerSecond;
        calls["file"]++;
    }

    function loanRates(uint) public returns(uint) {
        return call("loanRates");
    }

    function rates(uint) public view returns(uint, uint, uint, uint48,uint) {
        return (values_return["rates_pie"], values_return["rates_chi"], values_return["rates_ratePerSecond"], 0, 0);
    }

}
