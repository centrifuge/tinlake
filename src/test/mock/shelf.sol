pragma solidity >=0.4.24;

contract ShelfMock {

    //calls
    uint public releaseCalls;
    uint public depositCalls;

    uint public bags = 0; function setBags(uint bags_) public {bags=bags_;}

    uint public loan;
    address public usr;

    function release (uint loan_, address usr_) public {
        loan = loan_;
        usr = usr_;
        releaseCalls++;
    }

    function deposit (uint loan_, address usr_) public {
        loan = loan_;
        usr = usr_;
        depositCalls++;
    }
}
