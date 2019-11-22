pragma solidity >=0.4.24;

// Tranche Manager
contract LifeguardMock {

    // calls
    uint public callsBalance;

    function balance() public {
        callsBalance++;
        // internally triggers Operator
    }
}
