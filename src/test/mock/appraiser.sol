pragma solidity >=0.4.24;

contract AppraiserMock {
    uint public callsFile;

    uint public loan;
    uint public value;

    uint public appraiseReturn; function setAppraiseReturn(uint appraiseReturn_) public {appraiseReturn = appraiseReturn_;}

    function file (uint loan_, uint value_) public {
        callsFile++;
        loan = loan_;
        value = value_;
    }

    function appraise (uint loan_) public returns (uint) {
        loan = loan_;
        return appraiseReturn;
    }
}
