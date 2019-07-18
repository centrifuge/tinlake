pragma solidity >=0.4.24;

contract ShelfMock {

    //calls
    uint public releaseCalls;
    uint public depositCalls;
    uint public fileCalls;

    uint public bags = 0; function setBags(uint bags_) public {bags=bags_;}

    uint public loan;
    address public usr;
    address public registry;
    uint public nft;
    uint public principal;

    struct Loan {
        address registry;
        uint256 tokenId;
        uint price; //
        uint principal;

    }

    Loan public shelfReturn;
    function setShelfReturn(address registry_, uint256 tokenId_,uint price_, uint principal_) public {
        shelfReturn = Loan(registry_, tokenId_, price_, principal_);
    }

    function shelf(uint loan) public returns (address registry,uint256 tokenId,uint price,uint principal) {
        return (shelfReturn.registry,shelfReturn.tokenId, shelfReturn.price, shelfReturn.principal);
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
        fileCalls++;
    }

    function file(uint loan_, uint principal_) public {
        principal = principal_;
        fileCalls++;
    }
}
