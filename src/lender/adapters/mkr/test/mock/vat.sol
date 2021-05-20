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
pragma solidity >=0.6.12;
import "ds-test/test.sol";

import "../../../../../test/mock/mock.sol";

contract VatMock is Mock {
    function urns(bytes32, address) external view returns (uint, uint) {
        return (values_return["ink"], values_uint["tab"]);
    }

    function setInk(uint amountDROP) external {
        values_return["ink"] = amountDROP;
    }


    function increaseTab(uint amountDAI) external {
        values_uint["tab"] = safeAdd(values_uint["tab"], amountDAI);
    }

    function decreaseTab(uint amountDAI) external {
        values_uint["tab"] = safeSub(values_uint["tab"], amountDAI);
    }

    function ilks(bytes32) external view returns(uint, uint, uint, uint, uint)  {
        return(0, values_return["stabilityFeeIdx"], 0, 0, 0);
    }
}
