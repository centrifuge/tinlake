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
pragma experimental ABIEncoderV2;

contract AdmitLike {
    function admit (address registry, uint nft, uint principal, address usr) public returns(uint);
}

contract AppraiserLike {
    function file (uint loan, uint value) public;
}

contract PileLike {
    function file(uint loan, uint fee_, uint balance_) public;
    function file(uint fee, uint speed_) public;
    function fees(uint) public view returns(uint, uint, uint, uint);
}

// Admin can add whitelist a token and set the amount that can be borrowed against it. It also sets the borrowers rate in the Pile.
contract Admin {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    AdmitLike admit;
    AppraiserLike appraiser;
    PileLike pile;

    event Whitelisted(uint loan);

    constructor (address admit_, address appraiser_, address pile_) public {
        wards[msg.sender] = 1;
        admit = AdmitLike(admit_);
        appraiser = AppraiserLike(appraiser_);
        pile = PileLike(pile_);

    }

    // -- Whitelist --
    function whitelist(address registry, uint nft, uint principal, uint appraisal, uint fee, address usr) public auth returns(uint) {
        uint loan = admit.admit(registry, nft, principal, usr);
        appraiser.file(loan, appraisal);

        (,,uint speed,) = pile.fees(loan);
        if (speed == 0) {
            pile.file(fee, fee);
        }
        pile.file(loan, fee, 0);
        emit Whitelisted(loan);
        return loan;
    }
}

