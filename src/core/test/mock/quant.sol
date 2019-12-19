pragma solidity >=0.4.24;

contract QuantMock {

    uint public callsUpdateBorrowRate;
    uint public callsUpdateDebt;
    uint public callsDrip;
    uint public callsFile;

    uint public supplyRate;
    uint public rate;
    uint public reserve;
    int public loanAmount;

    function file(bytes32 what, uint rate_) public {
        rate = rate_;
        callsFile++;
    }

    function updateBorrowRate() public { 
        callsUpdateBorrowRate++;
    }

    function drip() public {
        callsDrip++;
    }

    function updateDebt(int loanAmount_) public  {
        loanAmount = loanAmount_;
        callsUpdateDebt++;
    }
}
