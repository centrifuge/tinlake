pragma solidity >=0.4.24;

contract ReserveMock {

    uint public callsSupply;
    uint public callsRedeem;
    uint public callsGive;
    uint public callsTake;

    uint public wadT;
    uint public wadS;
    address public usr;

    uint public sliceReturn; function setSliceReturn(uint wadS_) public {sliceReturn=wadS_;}
    uint public balance; function setBalanceReturn(uint wadT_) public {balance=wadT_;}
    
    function supply(address usr_, uint wadS_, uint wadT_) public returns(uint) {
       usr = usr_;
       wadT = wadT_;
       wadS = wadS_;
       callsSupply++;
    }

    function redeem(address usr_, uint wadS_, uint wadT_) public {
       usr = usr_;
       wadT = wadT_;
       wadS = wadS_;
       callsRedeem++;
    }

    function give(address usr_, uint wadT_) public {
       usr = usr_;
       wadT = wadT_;
       callsGive++;
    }

    function take(address usr_, uint wadT_) public {
       usr = usr_;
       wadT = wadT_;
       callsTake++;
    }

    function sliceOf(address usr_) public returns(uint) {
       return sliceReturn;
    }
}
