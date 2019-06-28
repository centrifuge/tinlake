pragma solidity >=0.4.24;

contract LenderTokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
    function balanceOf(address usr) public returns (uint);
}

contract BackerFab {
    function deploy(address tkn_, address collateral_,address backer, address lightswitch_) public returns (address) {
        Backer lender = new Backer(tkn_, collateral_,backer );
        lender.rely(msg.sender);
        return address(lender);
    }
}

contract Backer {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    LenderTokenLike public tkn;
    LenderTokenLike public collateral;

    address private backer;

    constructor (address tkn_, address collateral_, address backer_) public {
        wards[msg.sender] = 1;
        tkn = LenderTokenLike(tkn_);
        collateral = LenderTokenLike(collateral_);
        backer = backer_;
    }

    // --- Backer Methods ---
    function provide(address usrC, address usrT, uint wadC, uint wadT) auth public {
        require(tkn.balanceOf(backer)>= wadT);
        collateral.transferFrom(usrC, backer, wadC);
        tkn.transferFrom(backer,usrT, wadT);

    }

    function release(address usrC, address usrT, uint wadC, uint wadT) auth  public {
        require(collateral.balanceOf(backer)>= wadC);
        tkn.transferFrom(usrT,backer, wadT);
        collateral.transferFrom(backer, usrC, wadC);
    }

    function setBacker(address usr) auth public {
        backer = usr;
    }

}
