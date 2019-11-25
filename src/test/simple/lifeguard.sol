pragma solidity >=0.4.24;

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
}

contract PileLike {
    function want() public returns (int);
}


contract SimpleTrancheManagerFab {
    function deploy(address pile_, address token_, address lightswitch_) public returns (address) {
        SimpleTrancheManager manager = new SimpleTrancheManager(pile_, token_);
        return address(manager);
    }
}

// Tranche Manager
contract SimpleTrancheManager {

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
            give(address(pile), uint(wadT));

        } else {
            take(address(pile), uint(wadT*-1));
        }
    }

    // --- Operator Methods ---
    function give(address usrT, uint wadT) public {
        tkn.mint(usrT, wadT);
    }

    function take(address usrT, uint wadT) public {
        tkn.transferFrom(usrT, address(this), wadT);
    }

}
