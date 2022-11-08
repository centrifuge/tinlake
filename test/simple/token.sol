// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";
import "tinlake-erc20/erc20.sol";

contract SimpleToken is Math, ERC20 {
    
    constructor(string memory symbol_, string memory name_) ERC20(symbol, name) {}

    // --- Token ---
    function mint(address usr, uint wad) public override {
        balanceOf[usr] = safeAdd(balanceOf[usr], wad);
        totalSupply    = safeAdd(totalSupply, wad);
        emit Transfer(address(0), usr, wad);
    }
}
