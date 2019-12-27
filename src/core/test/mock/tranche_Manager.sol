pragma solidity >=0.4.24;

contract TrancheManagerMock {

    // calls
    uint public callsBalance;
    uint public callsReduce;

    bool public isEquityReturn; function setIsEquityReturn(bool isEquity) public {isEquityReturn=isEquity;}
    uint public poolValueReturn; function setPoolValueReturn(uint poolValue) public {poolValueReturn=poolValue;}
    uint public wad;
    address operator;

    // --- Tranches ---
    struct Tranche {
        uint ratio;
        address operator;
    }

    Tranche[] public tranches;

    function balance() public {
        callsBalance++;
    }

    function reduce(uint wad_) public  {
        wad = wad_;
        callsReduce++;
    }

    function trancheCount() public returns (uint) {
        return tranches.length;
    }

    function isEquity(address operator_) public returns (bool) {
        operator = operator_;
        return isEquityReturn;
    }

    function poolValue() public returns (uint) {
        return poolValueReturn;
    }

    function addTranche(uint ratio, address operator_) public {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = operator_;
        tranches.push(t);
    }

    function indexOf(address operator_) public returns (int) {
       for (uint i = 0; i < tranches.length; i++) {
            if (tranches[i].operator == operator_) {
                return int(i);
            }
        }
        return -1;
    }

    function operatorOf(uint i) public returns (address) {
        return tranches[i].operator;
    }
}

    