pragma solidity >=0.4.24;

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
}

contract ShelfLike {
    function balanceRequest() public returns (bool, uint);
}

contract TrancheManager {

    // --- Data ---
    ShelfLike public shelf;
    // simple tranche manager = 1 tranche/1 operator for now
    TokenLike public token;
    constructor (address shelf_, address token_) public {
        token = TokenLike(token_);
        shelf = ShelfLike(shelf_);
    }

    // --- Calls ---
    function balance() public {
        (bool want, uint wad)  = shelf.balanceRequest();
        
        if (wad == 0) {
            return;
        }

        if (want) {
            give(address(shelf), wad);
        } else {
            take(address(shelf), wad);
        }
    }

    function give(address usr, uint wad) public {
        token.mint(usr, wad);
    }

    function take(address usr, uint wad) public {
        token.transferFrom(usr, address(this), wad);
    }

}