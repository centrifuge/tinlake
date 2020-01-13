// admit.sol -- allows whitelisting assets on Tinlake
// Copyright (C) 2019 lucasvo

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

contract TitleLike {
    function issue (address usr) public returns (uint);
}

contract ShelfLike {
    function file(uint loan, address registry, uint nft) public;
    function shelf(uint loan) public returns(address registry, uint256 tokenId);
}

//e.g principal or credit-line
contract CeilingLike {
    function values(uint) public view returns(uint);
    function file(uint loan, uint ceiling) public;
}

// Admit can add whitelist a token and set the amount that can be borrowed against it. It also sets the borrowers rate in the Pile.
contract Admit {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TitleLike title;
    ShelfLike shelf;
    CeilingLike ceiling;

    event Created(uint loan); 

    constructor (address title_, address shelf_, address ceiling_) public {
        wards[msg.sender] = 1;
        title = TitleLike(title_);
        shelf = ShelfLike(shelf_);
        ceiling = CeilingLike(ceiling_);
    }

    function depend(bytes32 what, address addr) public auth {
        if (what == "shelf") { shelf = ShelfLike(addr); }
        if (what == "ceiling") { ceiling = CeilingLike(addr); }
        else revert();
    }
    
    // --- Admit ---
    function admit(address registry, uint nft, uint principal, address usr) public auth returns (uint) {
        uint loan = title.issue(usr);
        ceiling.file(loan, principal);
        shelf.file(loan, registry, nft);
        return loan;
    }

    function update(uint loan, address registry_, uint nft_, uint principal_) public auth {
        uint principal = ceiling.values(loan);

        // loan status should be whitelisted
        require(principal != 0, "loan not whitelisted");
        shelf.file(loan, registry_, nft_);
        ceiling.file(loan, principal);
    }

    function update(uint loan, uint principal_) public auth {
        uint principal = ceiling.values(loan);

        // loan status should be whitelisted
        require(principal != 0, "loan not whitelisted");
        ceiling.file(loan, principal_);
    }
}

