pragma solidity >=0.4.24;

contract QuantMock {

    uint public callsUpdateITake;
    uint public callsUpdateDebt;
    uint public callsDrip;
    uint public callsFile;

    uint public supplySpeed;
    uint public speed;
    uint public reserve;
    int public wad;

    uint public speedReturn; function setSpeedReturn(uint speed_) public {speedReturn=speed_;}
    uint public debt; function setDebtReturn(uint debt_) public {debt=debt_;}

    function file(bytes32 what, uint speed_) public {
        speed = speed_;
        callsFile++;
    }

    function updateITake(uint supplySpeed_, uint reserve_) public { 
        supplySpeed = supplySpeed_;
        reserve = reserve_;
        callsUpdateITake++;
    }

    function drip() public {
        callsDrip++;
    }

    function updateDebt(int wad_) public  {
        wad = wad_;
        callsUpdateDebt++;
    }

    function getSpeed() public returns(uint){
        return speedReturn;
    }

}
