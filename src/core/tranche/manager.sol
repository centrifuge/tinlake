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
    OperatorLike public senior;
    OperatorLike public junior;

    // dominated in RAD
    // ratio of the junior tranche in percent
    uint public juniorRatio;

    bool public poolClosing;

    constructor (address pile_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
        poolClosing = false;
    }

    uint constant ONE = 10 ** 27;

    function seniorRatio() public returns(uint) {
        return ONE - juniorRatio;
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "distributor") { distributor = DistributorLike(addr); }
        else revert();
    }

    function file(bytes32 what, bool data) public auth {
        if (what == "poolClosing") { poolClosing = data; }
        else revert();
    }

    function file(bytes32 what, uint ratio) public auth {
        if (what == "juniorRatio") { juniorRatio = ratio; }
        else revert();
    }

    // --- Calls ---
    function setTranche(bytes32 tranche, address operator_) public auth {
        if (tranche == "junior") { junior = OperatorLike(operator_); }
        else if (tranche == "senior") { senior = OperatorLike(operator_); }
        else revert();
    }

    function balance() public auth {
        distributor.balance();
    }

    uint public ActionTake = 1;
    uint public ActionGive = 2;

    function requestAction() public auth returns (uint, uint){
        int amount = pile.want();

        if (amount >= 0 ) {
            return (ActionTake, uint(amount));
        }
        if (amount <= 0) {
            return (ActionGive, uint(amount*-1));
        }
        return (0, 0);
    }
}