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
import "./mock/title.sol";
import "./mock/shelf.sol";
import "./mock/ceiling.sol";

contract AdmitTest is DSTest {
    Admit admit;
    TitleMock title;
    ShelfMock shelf;
    CeilingMock ceiling;

    address self;

    function setUp() public {
        self = address(this);
        title = new TitleMock();
        shelf = new ShelfMock();
        ceiling = new CeilingMock();
        admit = new Admit(address(title), address(shelf), address(ceiling));
    }

    function doAdmit(uint loan, address registry, uint nft, uint principal) public {
        uint loanId = admit.admit(registry, nft, principal, self);
        assertEq(shelf.callsFile(), 1);
        assertEq(shelf.nft(), nft);
        assertEq(shelf.registry(), registry);
        assertEq(title.usr(), self);
        assertEq(title.issueCalls(), 1);
        assertEq(ceiling.callsFile(), 1);
        assertEq(ceiling.wad(), principal);
        assertEq(loanId, loan);
    }

    function testAdmit() public {
        uint loan = 97;
        address registry = address(1);

        uint nft = 2;
        uint principal = 3;
        title.setIssueReturn(loan);
        doAdmit(loan, registry, nft, principal);
    }

    function testUpdate() public {
        uint loan = 97;
        address registry = address(1);
        uint nft = 2;
        uint principal = 3;
        title.setIssueReturn(loan);
        shelf.setLoanReturn(registry, nft);
        doAdmit(loan, registry, nft, principal);
    
        // update
        principal = 4;
        ceiling.setCeilingReturn(principal);
        admit.update(loan, principal);
    
        assertEq(ceiling.wad(), principal);
        assertEq(ceiling.callsFile(), 2);
    }

    function testFullUpdate() public {
        uint loan = 97;
        address registry = address(1);
        uint nft = 2;
        uint principal = 3;

        title.setIssueReturn(loan);
        shelf.setLoanReturn(registry, nft);

        doAdmit(loan, registry, nft, principal);

        principal = 4;
        nft = 12;
        registry = address(2);
        ceiling.setCeilingReturn(principal);
        admit.update(loan, registry, nft, principal);
       
        assertEq(ceiling.wad(), principal);
        assertEq(ceiling.callsFile(), 2);
        assertEq(shelf.callsFile(), 2);
    }

    function testFailUpdate() public {
        uint loan = 1;
        uint principal = 4;
        admit.update(loan, principal);
    }
}
