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

import "../../../test/mock/mock.sol";

contract CoordinatorMock is Mock {
    function submissionPeriod() public returns (bool) {
        calls["submissionPeriod"]++;
        return values_bool_return["submissionPeriod"];
    }

    function validate(uint seniorRedeem, uint juniorRedeem, uint seniorSupply, uint juniorSupply) public returns (int) {
        values_uint["seniorRedeem"] = seniorRedeem;
        values_uint["juniorRedeem"] = juniorRedeem;
        values_uint["seniorSupply"] = seniorSupply;
        values_uint["juniorSupply"] = juniorSupply;
        calls["validate"]++;
        return values_int_return["validate"];
    }
}