pragma solidity >=0.4.24;

contract LenderTokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
}

contract SimpleLenderFab {
    function deploy(address tkn_, address collateral_, address lightswitch_) public returns (address) {
        SimpleLender lender = new SimpleLender(tkn_, collateral_);
        lender.rely(msg.sender);
        return address(lender);
    }
}

contract SimpleLender {
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

    // --- Lender Methods ---
    function provide(address usrC, address usrT, uint wadC, uint wadT) public {
        collateral.transferFrom(usrC, address(this), wadC);
        tkn.mint(usrT, wadT);
    }

    function release(address usrC, address usrT, uint wadC, uint wadT) public {
        tkn.transferFrom(usrT,address(this), wadT);
        collateral.transferFrom(address(this), usrC, wadC);
    }

    function free(address usr, uint wad) public {
        revert();
    }
}
