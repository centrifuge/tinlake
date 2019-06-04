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
    function issue (address) public returns (uint); 
}

contract ShelfLike {
    function file(uint, address, uint, uint) public; 
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

    event Created(uint loan); 

    constructor (address title_, address shelf_) public {
        wards[msg.sender] = 1;
        title = TitleLike(title_);
        shelf = ShelfLike(shelf_);
    }
    
    // --- Admit ---
    function admit (address registry, uint nft, uint principal, address usr) public auth returns (uint) {
        uint loan = title.issue(usr);
        shelf.file(loan, registry, nft, principal);
        emit Created(loan);
        return loan;
    }
}

