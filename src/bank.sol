// Copyright (C) 2019 lucasvo
pragma solidity >=0.4.24;

import "./lib.sol";

// Bank 
// Manages the balance for the currency ERC20 in which borrowers want to borrow. 
contract Bank {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) public auth { wards[guy] = 1; }
    function deny(address guy) public auth { wards[guy] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike public tkn;

    constructor(address tkn_, uint roof_) public {
        wards[msg.sender] = 1;
        tkn = MintLike(tkn_);
        roof = roof_;
    }

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-add-overflow");
    }

    // --- Bank ---
    function settle(address usr, uint wad) public {
        // move currency into the borrowers account.
    }

    function repay(uint wad) public {
        // moves currency from sender to bank
    }
}
