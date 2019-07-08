// Copyright (C) 2019

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

import "./system.t.sol";
import "../../backer.sol";

contract BackerLike {
    function backer() public returns(address);
    function file(address usr) public;
}

contract BackerTest is DSTest, SystemTest {
    User b;
    address backerFab;

    function setUp() public {
        basicSetup();

        b = new User(address(deployer.reception()),tkn_, address(deployer.collateral()));
        tkn.mint(address(b), 1000 ether);

        backerFab = address(new BackerFab(address(b)));
        address lender_ = deployer.deployLender(tkn_, backerFab);

        b.doApproveCurrency(lender_, 1000 ether);
        b.doApproveCollateral(lender_, 1000 ether);

    }

    // lenderTokenAddr returns the address which holds the currency or collateral token for the lender
    function lenderTokenAddr(address lender) public returns(address) {
        return BackerLike(lender).backer();
    }

}


