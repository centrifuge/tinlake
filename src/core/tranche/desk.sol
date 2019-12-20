// Copyright (C) 2019 Centrifuge
//
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

import "ds-note/note.sol";

contract DistributorLike {
    function handleFlow(bool, bool) public;
    function addTranche(uint, address) public;
    function ratioOf(uint) public returns (uint);
}

// Desk
// Keeps track of the tranches. Manages the interfacing between the tranche side and borrower side of the contracts.
contract Desk is DSNote {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    DistributorLike public distributor;

    bool public flowThrough;
    bool public poolClosing;

    constructor (address distributor_) public {
        wards[msg.sender] = 1;
        distributor = DistributorLike(distributor_);
        flowThrough = false;
        poolClosing = false;
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "distributor") { distributor = DistributorLike(addr); }
        else revert();
    }

    function file(bytes32 what, bool data) public auth {
        if (what == "flowThrough") { flowThrough = data; }
        if (what == "poolClosing") { poolClosing = data; }
    }

    // --- Calls ---

    // TIN tranche should always be added first
    function addTranche(uint ratio, address operator_) public auth {
        distributor.addTranche(ratio, operator_);
    }

    function ratioOf(uint i) public auth returns (uint) {
        return distributor.ratioOf(i);
    }

    function balance() public auth {
        distributor.handleFlow(flowThrough, poolClosing);
    }
}