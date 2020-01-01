pragma solidity >=0.4.24;

contract ShelfMock {

    //calls
    uint public releaseCalls;
    uint public depositCalls;
    uint public fileCalls;
    uint public adjustCalls;
    uint public claimCalls;

    uint public bags = 0; function setBags(uint bags_) public {bags=bags_;}

    uint public    loan;
    address public usr;
    address public registry;
    uint public    nft;
    uint public    principal;
    uint public    initial;
    uint public    price;

    function setShelfReturn(address registry_, uint nft_,uint price_, uint principal_) public {
        registry = registry_;
        nft = nft_;
        price = price_;
        principal = principal_;
    }

    function shelf(uint loan) public returns (address, uint, uint, uint)  {
        return (registry, nft, price, principal);
    }

    function token(uint loan) public returns (address, uint) {
        return (registry, nft);
    }

    function adjust(uint loan_) public {
        loan = loan_;
        adjustCalls++;
    }

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

    function file(uint loan_, address registry_, uint nft_) public  {
        revert();
        loan = loan_;
        registry = registry_;
        nft = nft_;
        fileCalls++;
    }

    function file(uint loan_, address registry_, uint nft_, uint principal_) public  {
        loan = loan_;
        registry = registry_;
        nft = nft_;
        principal = principal_;
        initial = principal_;
        fileCalls++;
    }

    function file(uint loan_, uint principal_) public {
        principal = principal_;
        initial = principal;
        fileCalls++;
    }

    function claim(uint loan_, address usr_) public {
        loan = loan_;
        usr = usr_;
        claimCalls++;
    }
}
