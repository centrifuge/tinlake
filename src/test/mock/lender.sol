pragma solidity >=0.4.24;

contract LenderMock {

    // calls
    uint public provideCalls;
    uint public releaseCalls;
    uint public freeCalls;

    // variables
    address public usrC;
    address public usrT;
    uint public wadC;
    uint public wadT;

    address public usr;
    uint public wad;

    // --- Lender Methods ---
    function provide(address usrC_, address usrT_, uint wadC_, uint wadT_) public {
        usrC = usrC_;
        usrT = usrT_;
        wadC = wadC_;
        wadT = wadT_;
        provideCalls++;
    }

    function release(address usrC_, address usrT_, uint wadC_, uint wadT_) public {
        usrC = usrC_;
        usrT = usrT_;
        wadC = wadC_;
        wadT = wadT_;
        releaseCalls++;
    }

    function free(address usr_, uint wad_) public {
        usr = usr_;
        wad = wad_;
        freeCalls++;
    }
}