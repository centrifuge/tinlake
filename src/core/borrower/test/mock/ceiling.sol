pragma solidity >=0.5.12;

contract CeilingMock {
    uint public callsBorrow;
    uint public callsRepay;
    uint public callsFile;
    bool public ceilingReached; function setCeilingReached(bool ceilingReached_) public {ceilingReached=ceilingReached_;}
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
       require(!ceilingReached);
    }

    function repay(uint loan_, uint amount_) public {
       callsRepay++;
       amount = amount_;
       loan = loan_;
    }
    
    function file(uint loan_, uint wad_) public {
        callsFile++;
        loan = loan_;
        wad = wad_;
    }


}
