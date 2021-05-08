pragma solidity >=0.5.15 <0.6.0;
import "tinlake-auth/auth.sol";

interface DistTokenLike {
    function transferFrom(address, address, uint) external;
    function mint(address, uint) external;
}

interface DShelfLike {
    function balanceRequest() external returns (bool, uint);
}

contract Distributor is Auth {

    // --- Data ---
    DShelfLike public shelf;
    // simple tranche manager = 1 tranche/1 operator for now
    DistTokenLike public token;
    constructor (address token_) public {
        wards[msg.sender] = 1;
        token = DistTokenLike(token_);
    }

    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) public {
        if(contractName == "shelf") shelf = DShelfLike(addr);
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
        //token.mint(usr, wad);
        token.transferFrom(address(this), usr, wad);
    }

    function take(address usr, uint wad) public {
        token.transferFrom(usr, address(this), wad);
    }

}
