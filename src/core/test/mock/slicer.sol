pragma solidity >=0.4.24;

contract SlicerMock {

    uint public callsUpdateISupply;
    uint public callsDrip;
    uint public callsPayout;
    uint public callsChop;
    uint public callsFile;

    uint public takeSpeed;
    uint public speed;
    uint public debt;
    uint public reserve;
    uint public wadS;
    uint public wadT;
    int public wad;

    uint public chopReturn; function setChopReturn(uint wadS_) public {chopReturn=wadS_;}
    uint public payoutReturn; function setPayoutReturn(uint wadT_) public {payoutReturn=wadT_;}
    
    function file(bytes32 what, uint speed_) public {
        speed = speed_;
        callsFile++;
    }

    function updateISupply(uint takeSpeed_, uint debt_, uint reserve_) public { 
        takeSpeed = takeSpeed_;
        debt = debt_;
        reserve = reserve_;
        callsUpdateISupply++;
    }

    function drip() public {
        callsDrip++;
    }

    function chop(uint wadT_) public returns(uint) {
        wadT = wadT_;
        callsChop++;
        return chopReturn;
    }

    function payout(uint wadS_) public returns(uint) {
        wadS = wadS_;
        callsPayout++;
        return payoutReturn;
    }
}
