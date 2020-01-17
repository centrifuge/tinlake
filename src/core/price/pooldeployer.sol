// Copyright (C) 2020 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.12;

import {PricePool} from "../price/pool.sol";

contract PoolFab {
    function newPool() public returns (PricePool pool) {
        pool = new PricePool();
        pool.rely(msg.sender);
        pool.deny(address(this));
    }
}

//  can be combined into main deployer, just for now
contract PoolDeployer {
    PoolFab poolfab;

    address god;

    PricePool public pool;

    constructor(address god_, PoolFab poolFab_) public {
        poolfab = poolFab_;
    }

    function deployPool() public {
        pool = poolfab.newPool();
        // pile needs to be added here;
        pool.rely(god);
    }
}
