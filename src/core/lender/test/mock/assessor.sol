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

contract AssessorMock {

    address public senior;
    address public junior;

    mapping (bytes32 => uint) public calls;
    mapping (bytes32 => uint) public returnValues;


    function setReturn(bytes32 name, uint returnValue) public {
        returnValues[name] = returnValue;
    }

    function call(bytes32 name) internal returns (uint) {
        calls[name]++;
        return returnValues[name];
    }

    function calcTokenPrice () public returns (uint) {
        return call("tokenPrice");
    }

    function calcAssetValue(address tranche) public returns (uint) {
        return call("assetValue");
    }

    function juniorReserve() internal returns (uint) {
        return call("juniorReserve");
    }

    function seniorDebt() internal returns (uint) {
        return call("seniorDebt");
    }
}