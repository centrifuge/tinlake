pragma solidity >=0.4.24;

contract OperatorMock {

    uint public debtReturn; function setDebtReturn(uint debtReturn_) public {debtReturn=debtReturn_;}
    uint public balanceReturn; function setBalanceReturn(uint balanceReturn_) public {balanceReturn=balanceReturn_;}

    
    function debt() public returns (uint) {
        return debtReturn;
    }

    function balance() public returns (uint) {
        return balanceReturn;
    }
}
