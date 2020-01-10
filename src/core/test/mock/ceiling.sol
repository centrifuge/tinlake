pragma solidity >=0.4.24;

contract CeilingMock {
    uint public callsBorrow;
    uint public callsFile;
    bool public celeingReached; function setCeilingReached(bool celeingReached_) public {celeingReached=celeingReached_;}
    uint public ceilingReturn; function setCeilingReturn(uint ceiling) public {ceilingReturn=ceiling;}

    uint public amount;
    uint public loan;
    uint public wad;

    function values(uint loan) public view returns(uint) {
        return ceilingReturn;
    }

    function borrow (uint loan_, uint amount_) public {
       callsBorrow++;
       amount = amount_;
       loan = loan_;
       require(!celeingReached);
    }
    
    function file(uint loan_, uint wad_) public {
        callsFile++;
        loan = loan_;
        wad = wad_;
    }


}
