pragma solidity >=0.5.12;

contract TrancheManagerMock {

    // calls
    uint public callsBalance;
    uint public callsReduce;

    bool public isJuniorReturn; function setIsJuniorReturn(bool isJunior) public {isJuniorReturn=isJunior;}
    uint public poolValueReturn; function setPoolValueReturn(uint poolValue) public {poolValueReturn=poolValue;}
    uint public wad;
    address operator;

    // --- Tranches ---
    struct Tranche {
        uint ratio;
        address operator;
    }

    Tranche senior;
    Tranche junior;

    function balance() public {
        callsBalance++;
    }

    function reduce(uint wad_) public  {
        wad = wad_;
        callsReduce++;
    }

    function trancheCount() public returns (uint) {
        uint count = 0;
        if (junior.operator != address(0x0)) { count++; }
        if (senior.operator != address(0x0)) { count++; }
        return count;
    }

    function isJunior(address operator_) public returns (bool) {
        operator = operator_;
        return isJuniorReturn;
    }

    function poolValue() public returns (uint) {
        return poolValueReturn;
    }

    function addTranche(bytes32 what, uint ratio, address operator_) public {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = operator_;
        if (what == "junior") { junior = t; }
        else if (what == "senior") { senior = t; }
    }

    function juniorOperator() public returns (address) {
        return junior.operator;
    }

    function seniorOperator() public returns (address) {
        return senior.operator;
    }
}