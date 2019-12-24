pragma solidity >=0.4.24;

contract ReserveMock {

    uint public callsSupply;
    uint public callsRedeem;
    uint public callsRepay;
    uint public callsBorrow;

    uint public currencyAmount;
    uint public tokenAmount;
    address public usr;

    uint public sliceReturn; function setSliceReturn(uint tokenAmount_) public {sliceReturn=tokenAmount_;}
    uint public balance; function setBalanceReturn(uint currencyAmount_) public {balance=currencyAmount_;}
    
    function supply(address usr_, uint tokenAmount_, uint currencyAmount_) public  {
       usr = usr_;
       currencyAmount = currencyAmount_;
       tokenAmount = tokenAmount_;
       callsSupply++;
    }

    function redeem(address usr_, uint tokenAmount_, uint currencyAmount_) public {
       usr = usr_;
       currencyAmount = currencyAmount_;
       tokenAmount = tokenAmount_;
       callsRedeem++;
    }

    function repay(address usr_, uint currencyAmount_) public {
       usr = usr_;
       currencyAmount = currencyAmount_;
       callsRepay++;
    }

    function borrow(address usr_, uint currencyAmount_) public {
       usr = usr_;
       currencyAmount = currencyAmount_;
       callsBorrow++;
    }

    function sliceOf(address usr_) public returns(uint) {
       return sliceReturn;
    }
}
