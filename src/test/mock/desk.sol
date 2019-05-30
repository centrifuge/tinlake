pragma solidity >=0.4.24;

contract DeskMock {

    // calls
    uint public callsBalance;
    uint public callsReduce;

    uint public wad;

    function balance() public {
        callsBalance++;
    }

    function reduce(uint wad_) public  {
    wad = wad_;
    callsReduce++;
    }

}
