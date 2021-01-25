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

import "../../../../../test/mock/mock.sol";
import "./vat.sol";

contract ManagerMock is Mock {

    SimpleTokenLike currency;
    SimpleTokenLike collateral;
    VatMock vat;

    address public owner;

    modifier ownerOnly {
        require(msg.sender == owner, "TinlakeMgr/owner-only");
        _;
    }

    constructor(address currency_, address collateral_) public {
        owner = msg.sender;
        currency = SimpleTokenLike(currency_);
        collateral = SimpleTokenLike(collateral_);
    }

    function setVat(address vat_) external {
        vat = VatMock(vat_);
    }

    function ilk() public view returns (bytes32) {
        return values_bytes32_return["ilk"];
    }

    function join(uint amountDROP) external {
        // mimic cdp behav and transfer DROP from clerk to mgr
        collateral.transferFrom(msg.sender, address(this), amountDROP);
    }

    function draw(uint amountDAI) external  {
        // mimic cdp behav and mint DAI to clerk
        currency.mint(msg.sender, amountDAI);
        vat.increaseTab(amountDAI);

    }

    function wipe(uint amountDAI) external {
        // mimic cdp behav: move DAI from clerk to mgr
        currency.transferFrom(msg.sender, address(this), amountDAI);
        vat.decreaseTab(amountDAI);
    }

    function safe() external view returns(bool) {
        return values_bool_return["safe"];
    }

    function glad() external view returns(bool) {
        return values_bool_return["glad"];
    }

    function live() external view returns(bool) {
        return values_bool_return["live"];
    }

    function exit(uint amountDROP) external {
       collateral.transferFrom(address(this), msg.sender, amountDROP);
    }

    // --- Administration ---
    function setOwner(address newOwner) external ownerOnly {
        owner = newOwner;
    }
}
