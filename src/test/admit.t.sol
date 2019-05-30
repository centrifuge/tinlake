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

pragma solidity >=0.4.23;

import "ds-test/test.sol";

import { Admit } from "../admit.sol";

contract TitleMock {
    uint public calls;
    uint loan;
    address usr;

    constructor (address usr_, uint loan_) public {
       calls = 0;
       loan = loan_;
       usr = usr_;
    }   

    function issue (address usr_) public returns (uint) {
        calls = calls+1;
        require(usr == usr_, "bad-call"); 
        return loan;
    }
}

contract ShelfMock {
    uint public calls;
    uint loan;
    address registry;
    uint nft;
    uint principal;

    constructor (uint loan_, address registry_, uint nft_, uint principal_) public {
        loan = loan_;
        registry = registry_;
        nft = nft_;
        principal = principal_;
    }
    
    function file(uint loan_, address registry_, uint nft_, uint principal_) public {
        calls = calls+1;
        require(loan == loan_, "bad-call");
        require(registry == registry_, "bad-call");
        require(nft == nft_, "bad-call");
        require(principal == principal_, "bad-call");
    }
}

contract AdmitTest is DSTest {
    Admit admit;
    TitleMock title;
    ShelfMock shelf;
    
    uint loan;
    address usr;
    address self;
    address registry;
    uint nft;
    uint principal;
    
    function testAdmit() public {
        loan = 1;
        registry = address(1);
        nft = 2;
        principal = 3;
        title = new TitleMock(usr, loan);
        shelf  = new ShelfMock(loan, registry, nft, principal);

        admit = new Admit(address(title), address(shelf));

        uint loanR = admit.admit(registry, nft, principal, usr);
        assertEq(shelf.calls(), 1);
        assertEq(title.calls(), 1);
        assertEq(loan, loanR);
    }
}
