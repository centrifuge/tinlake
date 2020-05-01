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

contract OperatorLike {
    function supply(uint currencyAmount) public;
    function redeem(uint tokenAmount) public;
}

contract Investor {
    function doSupply(address operator, uint amount) public {
        OperatorLike(operator).supply(amount);
    }

    function doRedeem(address operator, uint amount) public {
        OperatorLike(operator).redeem(amount);
    }

}
