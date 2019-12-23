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
import "../lightswitch.sol";

contract PileLike {
    function want() public returns (int);
}

contract OperatorLike {}

contract DistributorLike {
    function balance() public;
    function repayTranches(uint) public;
}

// TrancheManager
// Keeps track of the tranches. Manages the interfacing between the tranche side and borrower side of the contracts.
contract TrancheManager is DSNote {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    DistributorLike public distributor;
    PileLike public pile;

    // --- Tranches ---

    struct Tranche {
        uint ratio;
        OperatorLike operator;
    }

    Tranche[] public tranches;

    bool public poolClosing;

    constructor (address pile_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
        poolClosing = false;
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        if (what == "distributor") { distributor = DistributorLike(addr); }
        else revert();
    }

    function file(bytes32 what, bool data) public auth {
        if (what == "poolClosing") { poolClosing = data; }
    }

    // --- Calls ---

    // TIN tranche should always be added first
    // We use 10ˆ27 for the ratio. For example, a ratio of 70% is 70 * 10^27 (70)
    function addTranche(uint ratio, address operator_) public auth {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = OperatorLike(operator_);
        tranches.push(t);
    }

    function balance() public auth {
        if (poolClosing) {
            distributor.repayTranches(uint(pile.want()*-1));
        } else {
            distributor.balance();
        }
    }

    function checkPile() public auth returns (int){
        return pile.want();
    }

    function trancheCount() public auth returns (uint) {
        return tranches.length;
    }

    function operatorOf(uint i) public auth returns (address) {
        return address(tranches[i].operator);
    }

    function ratioOf(uint i) public auth returns (uint) {
        return tranches[i].ratio;
    }

//    function getTrancheAssets() {
//
//    }
}