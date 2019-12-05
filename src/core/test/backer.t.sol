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

import "../backer.sol";
import "./mock/token.sol";



contract BackerTest is DSTest {
    TokenMock tkn;
    TokenMock collateral;

    Backer backer;

    address self;

    address backerAddr = 0x9458475477d1f98Ab45AFC138a787BEfaf8Ec48a;

    function setUp() public {
        tkn = new TokenMock();
        collateral = new TokenMock();

        self = address(this);
        backer = new Backer(address(tkn), address(collateral));
        backer.file(backerAddr);

    }

    function provide(uint wadC, uint wadT) public {
        tkn.setBalanceOfReturn(wadT);
        backer.provide(self, self, wadC, wadT);

        assertEq(tkn.transferFromCalls(), 1);
        assertEq(tkn.dst(),backerAddr);
        assertEq(tkn.src(),self);

        assertEq(collateral.transferFromCalls(), 1);
        assertEq(collateral.dst(),self);
        assertEq(collateral.src(),backerAddr);
    }

    function release(uint wadC, uint wadT) public {
        collateral.setBalanceOfReturn(wadC);
        backer.release(self, self, wadC, wadT);

        assertEq(tkn.transferFromCalls(), 1);
        assertEq(tkn.src(),backerAddr);
        assertEq(tkn.dst(),self);

        assertEq(collateral.transferFromCalls(), 1);
        assertEq(collateral.src(),self);
        assertEq(collateral.dst(),backerAddr);

    }

    function testProvide() public {
        uint wadC = 150;
        uint wadT = 100;
        provide(wadC, wadT);
    }

    function testRelease() public {
        uint wadC = 150;
        uint wadT = 100;
        release(wadC, wadT);
    }

    function testFile() public {
        uint wadC = 150;
        uint wadT = 100;

        address newBackerAddr = 0x1111111177D1f98aB45afc138A787BeFaf8eC48A;
        backer.file(newBackerAddr);
        backerAddr = newBackerAddr;
        provide(wadC, wadT);
    }
}
