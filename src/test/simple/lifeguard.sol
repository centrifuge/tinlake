pragma solidity >=0.4.24;

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
}

contract PileLike {
    function want() public returns (int);
}


contract SimpleLifeguardFab {
    function deploy(address pile_, address token_, address lightswitch_) public returns (address) {
        SimpleLifeguard lifeguard = new SimpleLifeguard(pile_, token_);
        lifeguard.rely(msg.sender);
        return address(lifeguard);
    }
}

// Tranche Manager
contract SimpleLifeguard {

    // --- Data ---
    PileLike public pile;
    // simple lifeguard = 1 tranche/1 operator for now
    TokenLike public token;
    constructor (address pile_, address token_) public {
        token = TokenLike(token_);
        pile = PileLike(pile_);
    }

    // --- Calls ---
    function balance() public {
        int wadT = pile.want();
        if (wadT > 0) {
            provide(address(pile), uint(wadT));

        } else {
            release(address(pile), uint(wadT*-1));
        }
    }

    // --- Operator Methods ---
    function provide(address usrT, uint wadT) public {
        tkn.mint(usrT, wadT);
    }

    function release(address usrT, uint wadT) public {
        tkn.transferFrom(usrT, address(this), wadT);
    }

    function free(address usr, uint wad) public {
        revert();
    }
}
