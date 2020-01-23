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

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import "./setup.sol";
import "tinlake-math/math.sol";

contract SystemTest is TestSetup, Math, DSTest {

    function baseSetup() public {
        // setup deployment
        deployContracts();

        // todo replace with investor contract
        rootAdmin.relyLenderAdmin(address(this));
    }

    function issueNFT(address usr) public returns (uint tokenId, bytes32 lookupId) {
        uint tokenId = collateralNFT.issue(usr);
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        return (tokenId, lookupId);
    }

    function setupCurrencyOnLender(uint amount) public {
        // mint currency
        currency.mint(address(this), amount);
        currency.approve(address(lenderDeployer.junior()), amount);
        uint balanceBefore = lenderDeployer.juniorERC20().balanceOf(address(this));
        // move currency into junior tranche
        address operator_ = address(lenderDeployer.juniorOperator());
        WhitelistOperator(operator_).relyInvestor(address(this));
        WhitelistOperator(operator_).supply(amount);
        // same amount of junior tokens
        assertEq(lenderDeployer.juniorERC20().balanceOf(address(this)), balanceBefore + amount);
    }

}