pragma solidity >=0.4.24;

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
}

contract PileLike {
    function want() public returns (int);
}

contract TrancheManagerFab {
    function deploy(address pile_, address token_) public returns (address) {
        TrancheManager manager = new TrancheManager(pile_, token_);
        return address(manager);
    }
}

contract TrancheManager {

    // --- Data ---
    PileLike public pile;
    // simple tranche manager = 1 tranche/1 operator for now
    TokenLike public token;
    constructor (address pile_, address token_) public {
        token = TokenLike(token_);
        pile = PileLike(pile_);
    }

    // --- Calls ---
    function balance() public {
        int wad = pile.want();
        if (wad > 0) {
            give(address(pile), uint(wad));

        } else {
            take(address(pile), uint(wad*-1));
        }
    }

    // --- Operator Methods ---
    function give(address usr, uint wad) public {
        tkn.mint(usr, wad);
    }

    function take(address usr, uint wad) public {
        tkn.transferFrom(usr, address(this), wad);
    }

}
