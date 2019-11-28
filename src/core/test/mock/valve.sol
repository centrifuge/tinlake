pragma solidity >=0.4.24;

import "./token.sol";

contract ValveMock {
    TokenMock public tkn;
    constructor () public {
        tkn = new TokenMock();
    }

    // calls
    uint public balanceCalls;
    uint public wantCalls;
    uint public mintCalls;
    uint public mintMaxCalls;
    uint public burnMaxCalls;

    // variables
    address public usr;
    uint public wad;

    // returns
    int public wantReturn; function setWantReturn(int wantReturn_) public {wantReturn = wantReturn_;}

    // --- Valve ---
    function balance(address usr_) public  {
        usr = usr_;
        balanceCalls++;
    }

    function want() public returns (int) {
        wantCalls++;
        return wantReturn;
    }

    function mint(address usr_, uint wad_) public  {
        usr = usr_;
        wad = wad_;
        mintCalls++;
    }

    function mintMax(address usr_) public  {
        usr = usr_;
        mintMaxCalls++;
    }

    function burnMax(address usr_) public  {
        usr = usr_;
        burnMaxCalls++;
    }
}
