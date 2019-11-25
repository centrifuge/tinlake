pragma solidity >=0.4.24;

import "../../lightswitch.sol";

contract TokenLike {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
}

contract PileLike {
    function want() public returns (int);
}

contract OperatorLike {
    function provide(address,address,uint,uint) public;
    function release(address,address,uint,uint) public;
    function free(address, uint) public;
}

contract SimpleLifeguardFab {
    function deploy(address pile_, address operator_, address lightswitch_) public returns (address) {
        SimpleLifeguard lifeguard = new SimpleLifeguard(pile_, operator_);
        lifeguard.rely(msg.sender);
        return address(lifeguard);
    }
}

// Tranche Manager
contract SimpleLifeguard {

    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    PileLike public pile;
    // simple lifeguard = 1 tranche/1 operator for now
    OperatorLike public operator;
    constructor (address pile_, address operator) public {
        wards[msg.sender] = 1;

        pile = PileLike(pile_);
    }

    // --- Calls ---
    function balance() public {
        int wadT = pile.want();
        if (wadT > 0) {
            operator.provide(address(pile), uint(wadT));

        } else {
            operator.release(address(pile), uint(wadT*-1));
        }
    }
}

contract SimpleOperator {

    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike public token;

    constructor (address token_) public {
        wards[msg.sender] = 1;
        token = TokenLike(token_);
    }

    // --- Lender Side Methods ---
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
