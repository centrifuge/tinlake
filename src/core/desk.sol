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

import "../../lib/dss-add-ilk-spell/lib/dss-deploy/lib/dss/src/lib.sol";

contract PileLike {
    function want() public returns (int);
}

contract DistributorLike {
    function waterfallRepay() public;
    function makerRepay() public;
}

contract OperatorLike {
    function borrow(address, uint) public;
    function repay(address, uint) public;
    function balance() public returns (uint);
    function file(bytes32, bool) public;

    bool public supplyActive;
    bool public redeemActive;
}

// Desk
// Keeps track of the tranches. Manages the interfacing between the tranche side and borrower side of the contracts.
contract Desk is DSNote {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Tranches ---

    struct Tranche {
        uint ratio;
        OperatorLike operator;
    }

    Tranche[] tranches;

    // --- Data ---
    PileLike public pile;
    DistributorLike public distributor;

    bool public flowThrough;

    constructor (address pile_, address distributor_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
        distributor = DistributorLike(distributor_);
        flowThrough = false;
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "distributor") { distributor = DistributorLike(addr); }
        else revert();
    }

    function file(bytes32 what, bool data) public auth {
        if (what == "flowThrough") { flowThrough = data; }
    }

    function file(uint i, bytes32 what, bool data) public auth {
        tranches[i].operator.file(what, data);
    }

    // --- Calls ---

    function addTranche(uint ratio, address operator_) public auth {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = OperatorLike(operator_);
        tranches.push(t);
    }

    function returnOperator(uint i) public auth returns (address){
       return address(tranches[i].operator);
    }

    function returnRatio(uint i) public auth returns (uint) {
        return tranches[i].ratio;
    }

    function balance(uint i) public auth {

        // balance methods should:
        // iterate through the tranches
        // quant debt =  how much is

        Tranche memory t = tranches[i];
        // if capital should flow through, all funds in reserve should be moved in pile
        if (flowThrough) {
            if (t.operator.supplyActive()) {
                // calculates how much money is in the reserve, transfers all of this balance to the pile
                uint wadR = t.operator.balance();
                t.operator.borrow(address(pile), uint(wadR));
            }
            if (t.operator.redeemActive()) {
                // payout
                distributor.waterfallRepay();
            }
        } else {
            int wad = pile.want();
            if (wad > 0) {
                // transfer from reserve only how much the pile wants
                t.operator.borrow(address(pile), uint(wad));
            } else {
                // this should take the money from the pile, repay and close the vault
                distributor.makerRepay();
                t.operator.repay(address(pile), uint(wad*-1));
            }
        }
    }
}