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

contract ManagerMock is Mock {

    SimpleTokenLike currency;
    SimpleTokenLike collateral;

    constructor(address currency_, address collateral_) public {
        currency = SimpleTokenLike(currency_);
        collateral = SimpleTokenLike(collateral_);
    }

    function cdptab() public view returns (uint) {
        return values_uint["tab"];
    }

    function ilk() public view returns (bytes32) {
        return values_bytes32_return["ilk"];
    }

    function join(uint amountDROP) external {
        // mimic cdp behav and transfer DROP from clerk to mgr
        collateral.transferFrom(msg.sender, address(this), amountDROP);
    }

    function draw(uint amountDAI, address usr) external  {
        // mimic cdp behav and mint DAI to clerk
        currency.mint(usr, amountDAI);
        values_uint["tab"] = safeAdd(values_uint["tab"], amountDAI);
    }

    function wipe(uint amountDAI) external {
        // mimic cdp behav: move DAI from clerk to mgr
        currency.transferFrom(msg.sender, address(this), amountDAI);
        values_uint["tab"] = safeSub(values_uint["tab"], amountDAI);
    }

    function safe() external returns(bool) {
        return values_bool_return["safe"];
    }

    function exit(address usr, uint amountDROP) external {
       collateral.transferFrom(address(this), usr, amountDROP);
    }

    function increaseTab(uint amountDAI) external {
        values_uint["tab"] = safeAdd(values_uint["tab"], amountDAI);
    }

}
