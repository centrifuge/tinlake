pragma solidity >=0.4.24;

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
}

contract PileLike {
    function want() public returns (int);
}

contract Desk {

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

    function give(address usr, uint wad) public {
        token.mint(usr, wad);
    }

    function take(address usr, uint wad) public {
        token.transferFrom(usr, address(this), wad);
    }

}
