pragma solidity >=0.4.24;

contract LenderTokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
}

contract BackerFab {
    function deploy(address tkn_, address collateral_, address lightswitch_) public returns (address) {
        Backer lender = new Backer(tkn_, collateral_);
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

    constructor (address tkn_, address collateral_) public {
        wards[msg.sender] = 1;
        tkn = LenderTokenLike(tkn_);
        collateral = LenderTokenLike(collateral_);
    }

    // --- Backer Methods ---
    function provide(address usrC, address usrT, uint wadC, uint wadT) auth public {
        collateral.transferFrom(usrC, address(this), wadC);
        require(tkn.balanceOf(address(this))>= wadT);
        tkn.transferFrom(address(this),usrT, wadT);

    }

    function release(address usrC, address usrT, uint wadC, uint wadT) auth  public {
        tkn.transferFrom(usrT,address(this), wadT);
        require(collateral.balanceOf(address(this))>= wadC);
        collateral.transferFrom(address(this), usrC, wadC);
    }

    function withdraw(address usr, uint wad) auth public {
        require(tkn.balanceOf(address(this))>= wad);
        tkn.transferFrom(address(this),usr, wad);
    }

    function withdrawCollateral(address usr, uint wad) auth public {
        require(collateral.balanceOf(address(this))>= wad);
        tkn.transferFrom(address(this),usr, wad);
    }



}
