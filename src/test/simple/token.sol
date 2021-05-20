// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico
pragma solidity >=0.6.12;

import "tinlake-math/math.sol";
import "../../lender/token/erc20.sol";

contract SimpleToken is Math, TinlakeERC20 {
    
    constructor(string memory symbol_, string memory name_) TinlakeERC20(symbol, name) public {}

    // --- Token ---
    function mint(address usr, uint wad) public override {
        balanceOf[usr] = safeAdd(balanceOf[usr], wad);
        totalSupply    = safeAdd(totalSupply, wad);
        emit Transfer(address(0), usr, wad);
    }
}
