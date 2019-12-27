pragma solidity >=0.4.24;

contract TrancheManagerMock {

    // calls
    uint public callsBalance;
    uint public callsReduce;

    bool public isSeniorReturn; function setIsSeniorReturn(bool isSenior) public {isSeniorReturn=isSenior;}
    uint public wad;
    address public trancheOperator;

    function balance() public {
        callsBalance++;
    }

    function reduce(uint wad_) public  {
        wad = wad_;
        callsReduce++;
    }

    function isSenior(address trancheOperator_) public returns (bool) {
        trancheOperator = trancheOperator_;
        return isSeniorReturn;
    }
}

    