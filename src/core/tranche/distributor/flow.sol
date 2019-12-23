// Copyright (C) 2019 Centrifuge

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

pragma solidity >=0.4.24;

contract FlowLike {
    function flow() public returns (uint);
}

contract Flowable {
    // --- Data ---
    FlowLike public distribution;

    constructor (address flow_) public {
        distribution = FlowLike(flow_);
    }
    // --- Flowable ---
    modifier trad { require(distribution.flow() == 1); _; }
    modifier maker { require(distribution.flow() == 0); _; }

}

contract Distribution {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    uint public flow;

    constructor () public {
        wards[msg.sender] = 1;
        flow = 1;
    }

    // --- Distribution ---
    function file(bytes32 what, uint data) public auth {
        require(data < 2);
        if (what == "flow") {flow = data;}
        else revert();
    }
}
