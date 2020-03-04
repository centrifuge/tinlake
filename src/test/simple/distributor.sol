pragma solidity >=0.5.3;
import "tinlake-auth/auth.sol";

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
}

contract ShelfLike {
    function balanceRequest() public returns (bool, uint);
}

contract Distributor is Auth {

    // --- Data ---
    ShelfLike public shelf;
    // simple tranche manager = 1 tranche/1 operator for now
    TokenLike public token;
    constructor (address token_) public {
        wards[msg.sender] = 1;
        token = TokenLike(token_);
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) public {
        if(contractName == "shelf") shelf = ShelfLike(addr);
        else revert();
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
