// spotter.sol the spotter monitors the pool detect collectable assets
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

contract ShelfLike {
    function adjust() public;
}

contract PileLike {
    function loans(uint loan) public returns (uint, uint, uint ,uint);
}

contract Spotter {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }


    ShelfLike public shelf;
    PileLike public pile;

    constructor(address shelf_, address pile_) {
        wards[msg.sender] = 1;
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
    }

    function file(bytes32 what, uint data) public auth {
        if (what == "threshold") threshold = data;
        else revert();
    }

    uint public threshold;

    function actPrice(uint loan) internal returns(uint) {
        shelf.adjust(loan);
        (,,uint price,) = shelf.shelf(loan);
        return price;
    }

    function actDebt(uint loan) internal returns(uint) {
        pile.collect(loan);
        (uint debt,,,) = pile.loans(loan);
        return debt;
    }

    function collectable(uint loan) public returns(bool) {
        uint price = actPrice(loan);
        uint debt = actDebt(loan);

        uint ratio = rdiv(price/debt);
        if(ratio >= threshold) {
            return true;
        }
        return false;
    }

}
