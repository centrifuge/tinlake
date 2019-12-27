pragma solidity >=0.4.24;

contract ReserveMock {

    uint public callsSupply;
    uint public callsRedeem;
    uint public callsRepay;
    uint public callsBorrow;

    uint public currencyAmount;
    uint public tokenAmount;
    address public usr;

    uint public tokenBalanceReturn; function setTokenBalanceReturn(uint tokenAmount_) public {tokenBalanceReturn=tokenAmount_;}
    uint public tokenSupplyReturn; function setTokenSupplyReturn(uint tokenAmount_) public {tokenSupplyReturn=tokenAmount_;}
    uint public balance; function setBalanceReturn(uint currencyAmount_) public {balance=currencyAmount_;}
    
    function tokenSupply() public returns(uint){
       return tokenSupplyReturn;
    }

    function supply(address usr_, uint tokenAmount_, uint currencyAmount_) public {
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

    function tokenBalanceOf(address usr_) public returns(uint) {
       return tokenBalanceReturn;
    }
}
