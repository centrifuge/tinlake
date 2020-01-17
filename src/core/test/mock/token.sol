pragma solidity >=0.4.24;

contract TokenMock {
    // calls
    uint public balanceOfCalls;
    uint public mintCalls;
    uint public transferFromCalls;
    uint public burnCalls;
    uint public approveCalls;

    // returns
    uint public balanceOfReturn; function setBalanceOfReturn(uint balanceOfReturn_) public {balanceOfReturn=balanceOfReturn_;}
    bool public approveReturn; function setApproveReturn(bool approveReturn_) public {approveReturn = approveReturn_;}
    // variables
    address public addr;
    uint public wad;
    address public dst;
    address public src;
    address public usr;

    uint public totalSupply;


    function balanceOf(address addr_) public view returns (uint) {
        return balanceOfReturn;
    }
    
    function mint(address addr_,uint wad_) public {
        addr = addr_;
        wad = wad_;
        mintCalls++;
    }

    function transferFrom(address dst_ ,address src_,uint wad_) public {
        dst = dst_;
        src = src_;
        wad = wad_;
        transferFromCalls++;

    }
    function burn(address addr_, uint wad_) public {
        addr=addr_;
        wad = wad_;
        burnCalls;
    }

    function approve(address usr_, uint wad_) public returns (bool) {
        usr = usr_;
        wad = wad_;
        approveCalls++;
        return approveReturn;
    }

}
