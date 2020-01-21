pragma solidity >=0.5.12;

import "../../../test/mock/mock.sol";

contract PileMock is Mock {
    function total() public returns(uint) {
        return call("total");
    }

//    function rates(uint loan) public view returns(uint, uint, uint, uint) {
//        return (rateReturn.pie, rateReturn.chi, rateReturn.speed, rateReturn.rho);
//    }

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
        values_uint["debt_loan"] = loan;
        return call("debt");
    }

    function debt() public returns(uint) {
        return call("debt");
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

    function file(uint rate, uint speed) public {
        values_uint["file_rate"] = rate;
        values_uint["file_speed"] = speed;
        calls["file"]++;
    }
}
