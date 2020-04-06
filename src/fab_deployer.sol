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

contract FabDeployer {
    function deploy(bytes memory bytecode, bytes32 salt) public returns (address fab)  {
        assembly {
            fab := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(fab)) { revert(0, 0) }
        }
    }

    /// returns address(0) if contract doesn't exist
    function getAddress(bytes memory bytecode, bytes32 salt) public view returns(address) {
        // create2 address calculation
        // name is used as salt
        // keccak256(0xff ++ deployingAddr ++ salt ++ keccak256(bytecode))[12:]
        bytes32 _data = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        );
        address fabAddress = address(bytes20(_data << 96));
        uint size;
        assembly {
            size := extcodesize(fabAddress)
        }
        if (size > 0) {
            return fabAddress;
        }
        return address(0);
    }
}

