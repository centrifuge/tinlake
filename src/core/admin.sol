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
    function update(uint loan, address registry, uint nft, uint principal) public;
    function update(uint loan, uint principal) public;
}

contract PileLike {
    function file(uint rate, uint speed_) public;
    function rates(uint) public view returns(uint, uint, uint, uint);
    function setRate(uint loan, uint rate) public;
    function changeRate(uint loan, uint rate) public;
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
    PileLike pile;

    event Whitelisted(uint loan);

    constructor (address admit_, address pile_) public {
        wards[msg.sender] = 1;
        admit = AdmitLike(admit_);
        pile = PileLike(pile_);
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "admit") { admit = AdmitLike(addr); }
        else revert();
    }

    // -- Whitelist --
    function whitelist(address registry, uint nft, uint principal, uint rate, address usr) public auth returns(uint) {
        uint loan = admit.admit(registry, nft, principal, usr);

        (,, uint speed,) = pile.rates(rate);
        require(speed != 0);
        
        pile.setRate(loan, rate);
        emit Whitelisted(loan);
        return loan;
    }

    function file(uint rate, uint speed) public auth {
        pile.file(rate, speed);
    }

    function update(uint loan, address registry, uint nft, uint principal, uint rate) public auth {
        admit.update(loan, registry, nft, principal);
        pile.changeRate(loan, rate);
    }

    function update(uint loan, uint principal) public auth  {
        admit.update(loan, principal);
    }

    function blacklist(uint loan) public auth {
        admit.update(loan, address(0), 0, 0);
        pile.changeRate(loan, 0);
    }
}

