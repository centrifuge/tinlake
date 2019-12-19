pragma solidity >=0.4.24;

contract QuantMock {

    uint public callsUpdateIBorrow;
    uint public callsUpdateDebt;
    uint public callsDrip;
    uint public callsFile;

    uint public supplySpeed;
    uint public speed;
    uint public reserve;
    int public loanAmount;

    uint public speedReturn; function setSpeedReturn(uint speed_) public {speedReturn=speed_;}
    uint public debt; function setDebtReturn(uint debt_) public {debt=debt_;}

    function file(bytes32 what, uint speed_) public {
        speed = speed_;
        callsFile++;
    }

    function UpdateIBorrow(uint supplySpeed_, uint reserve_) public { 
        supplySpeed = supplySpeed_;
        reserve = reserve_;
        callsUpdateIBorrow++;
    }

    function drip() public {
        callsDrip++;
    }

    function updateDebt(int loanAmount_) public  {
        loanAmount = loanAmount_;
        callsUpdateDebt++;
    }

    function getSpeed() public returns(uint){
        return speedReturn;
    }

}
