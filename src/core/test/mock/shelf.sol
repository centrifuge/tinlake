pragma solidity >=0.5.12;

contract ShelfMock {

    //calls
    uint public callsIssue;
    uint public callsLock;
    uint public callsUnlock;
    uint public callsFile;
    uint public callsClaim;
    uint public callsBorrow;
    uint public callsWithdraw;
    uint public callsRepay;
    uint public callsRecover;
    uint calls;
    bool returnRequestWant;
    uint returnAmount;

    uint public    loan;
    address public usr;
    address public registry;
    uint public    nft;
    uint public wad;

    function setReturn(bytes32 name, bool requestWant, uint amount) public {
        returnRequestWant = requestWant;
        returnAmount = amount;
    }
    
    function setLoanReturn(address registry_, uint nft_) public {
        registry = registry_;
        nft = nft_;
    }

    function shelf(uint loan) public returns (address, uint)  {
        return (registry, nft);
    }

    function token(uint loan) public returns (address, uint) {
        return (registry, nft);
    }

    function recover (uint loan_, address usr_, uint wad_) public {
        loan = loan_;
        usr = usr_;
        wad = wad_;
        callsRecover++;
    }

    function lock(uint loan_, address usr_) public {
        loan = loan_;
        usr = usr_;
        callsLock++;
    }

    function unlock(uint loan_, address usr_) public {
        loan = loan_;
        usr = usr_;
        callsUnlock++;
    }

    function claim(uint loan_, address usr_) public {
        loan = loan_;
        usr = usr_;
        callsClaim++;
    }

    function file(uint loan_, address registry_, uint nft_) public  {
        loan = loan_;
        registry = registry_;
        nft = nft_;
        callsFile++;
    }

    function balanceRequest() public returns (bool, uint) {
     return (returnRequestWant, returnAmount);
    }

}
