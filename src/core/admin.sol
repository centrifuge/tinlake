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

contract AppraiserLike {
    function file (uint loan, uint value) public;
}

contract PileLike {
    function file(uint loan, uint rate_, uint balance_) public;
}

contract DebtRegisterLike {
    function file(uint rate, uint speed_) public;
    function rates(uint) public view returns(uint, uint, uint, uint);
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
    DebtRegisterLike debtRegister;

    event Whitelisted(uint loan);

    constructor (address admit_, address appraiser_, address pile_, address debtRegister_) public {
        wards[msg.sender] = 1;
        admit = AdmitLike(admit_);
        appraiser = AppraiserLike(appraiser_);
        pile = PileLike(pile_);
        debtRegister = DebtRegisterLike(debtRegister_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else if (what == "admit") { admit = AdmitLike(addr); }
        else if (what == "appraiser") { appraiser = AppraiserLike(addr); }
        else if (what == "debtRegister") { debtRegister = DebtRegisterLike(addr); }
        else revert();
    }

    // -- Whitelist --
    function whitelist(address registry, uint nft, uint principal, uint appraisal, uint rate, address usr) public auth returns(uint) {
        uint loan = admit.admit(registry, nft, principal, usr);
        appraiser.file(loan, appraisal);

        (,, uint speed,) = debtRegister.rates(rate);
        require(speed != 0);

        pile.file(loan, rate, 0);
        emit Whitelisted(loan);
        return loan;
    }

    function file(uint rate, uint speed) public auth {
        debtRegister.file(rate, speed);
    }

    function update(uint loan, address registry, uint nft, uint principal, uint appraisal, uint rate) public auth {
        admit.update(loan, registry, nft, principal);
        appraiser.file(loan, appraisal);
        pile.file(loan, rate, 0);
    }

    function update(uint loan, uint principal, uint appraisal) public auth  {
        admit.update(loan, principal);
        appraiser.file(loan, appraisal);
    }

    function blacklist(uint loan) public auth {
        admit.update(loan, address(0), 0, 0);
        appraiser.file(loan, 0);
        pile.file(loan, 0, 0);
    }
}

