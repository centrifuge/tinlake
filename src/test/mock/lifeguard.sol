pragma solidity >=0.4.24;
pragma experimental ABIEncoderV2;


contract LifeguardMock {

    // calls
    uint public callsBalance;
    uint public callsGive;
    uint public callsTake;

    uint public wad;


    function balance() public {
        callsBalance++;
    }

    function give(uint wad_) public  {
        wad = wad_;
        callsGive++;
    }

    function take(uint wad_) public  {
        wad = wad_;
        callsTake++;
    }
}
