pragma solidity >=0.4.24;


import "./token.sol";

contract TknMock {
    uint public approveCalls;

    address public usr;
    uint public wad;
    function approve(address usr_, uint wad_) public {
        approveCalls++;
        usr = usr_;
        wad = wad_;
    }
}


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
        balanceCalls++;
        usr = usr_;

    }

    function want() public returns (int) {
        wantCalls++;
        return wantReturn;
    }

    function mint(address usr_, uint wad_) public  {
        mintCalls++;
        usr = usr_;
        wad = wad_;
    }

    function mintMax(address usr_) public  {
        mintMaxCalls++;
        usr = usr_;
    }

    function burnMax(address usr_) public  {
        burnMaxCalls++;
        usr = usr_;
    }
}
