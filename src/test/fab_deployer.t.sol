// Copyright (C) 2020 Centrifuge

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

pragma solidity >=0.5.15 <0.6.0;

import "ds-test/test.sol";
import "./../fab_deployer.sol";
import "./../borrower/deployer.sol";


contract FabDeployerTest is DSTest {
    FabDeployer fabDeployer;

    function setUp() public {
        fabDeployer = new FabDeployer();
    }

    function testFabDeploy() public {
        bytes memory pileFabBytes = type(PileFab).creationCode;
        // fab should not exist
        assertEq(fabDeployer.getAddress(pileFabBytes, "pileFab"), address(0));

        fabDeployer.deploy(pileFabBytes, "pileFab");

        address pileFab_ = fabDeployer.getAddress(pileFabBytes, "pileFab");
        assertTrue(pileFab_ != address(0));

        PileFab pileFab = PileFab(pileFab_);
        address pile_ = pileFab.newPile();

        Pile pile = Pile(pile_);
        assertEq(pile.wards(address(this)), 1);
    }

}
