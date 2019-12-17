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

contract PileLike {
    function want() public returns (int);
}

contract DistributorLike {
    function waterfallGive() public;
}

contract OperatorLike {
    function give(address, uint) public;
    function take(address, uint) public;
    boolean public supplyActive;
    boolean public redeemActive;
}

contract Desk {

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

    // --- Calls ---

    function addTranche(uint ratio, address operator_) public auth {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = OperatorLike(operator_);
        tranches.push(t);
    }

    function returnOperator(uint i) public auth {
       return tranches[i].operator;
    }

    function returnRatio(uint i) public auth {
        return tranches[i].ratio;
    }

    function balance() public auth {
        if (flowThrough) {
            if (operator.supplyActive) {
                        //operator.balance()
              uint wadR = reserve.balance();
              operator.take(address.pile, uint(wadR));
            }
            if (operator.redeemActive) {
                // payout
                distributor.waterfallGive();
            }
        } else {
            int wad = pile.want();
            if (wad > 0) {
                // this should open MCD Vault and take DAI into reserve
                operator.take(address(pile), uint(wad));
            } else {
                // this should repay Vault
                operator.give(address(pile), uint(wad*-1));
            }
        }
    }
}