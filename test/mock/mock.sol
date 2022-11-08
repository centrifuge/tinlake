// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import "forge-std/Test.sol";
import "tinlake-math/math.sol";

interface SimpleTokenLike {
    function balanceOf(address) external view returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function mint(address, uint) external;
    function burn(address, uint) external;
    function totalSupply() external view returns (uint);
    function approve(address usr, uint amount) external;
}

contract Mock is Test, Math {
    // counting calls
    mapping (bytes32 => uint) public calls;

    // returns
    mapping (bytes32 => uint) public values_return;
    mapping (bytes32 => address) public values_address_return;
    mapping (bytes32 => bool) public values_bool_return;
    mapping (bytes32 => int) public values_int_return;
    mapping (bytes32 => bytes32) public values_bytes32_return;

    // passed parameter
    mapping (bytes32 => uint) public values_uint;
    mapping (bytes32 => address) public values_address;
    mapping (bytes32 => bytes32) public values_bytes32;

    mapping (bytes32 =>bool) method_fail;

    // function values(bytes32 name) public returns (uint) {return values_uint[name];}
    // function values(bytes32 name) public returns (address) {return values_address[name];}

    function call(bytes32 name) internal returns (uint) {
        calls[name]++;
        return values_return[name];
    }

    function setReturn(bytes32 name, uint returnValue) public {
        values_return[name] = returnValue;
    }

    function setReturn(bytes32 name, bool returnValue) public {
        values_bool_return[name] = returnValue;
    }

    function setBytes32Return(bytes32 name, bytes32 returnValue) public {
        values_bytes32_return[name] = returnValue;
    }

    function setIntReturn(bytes32 name, int returnValue) public {
        values_int_return[name] = returnValue;
    }

    function setReturn(bytes32 name, bool flag, uint value) public {
        setReturn(name, flag);
        setReturn(name, value);
    }

    function setReturn(bytes32 name, address addr, uint value) public {
        setReturn(name, addr);
        setReturn(name, value);
    }

    function setReturn(bytes32 name, address returnValue) public {
        values_address_return[name] = returnValue;
    }

    function setFail(bytes32 name, bool flag) public {
        method_fail[name] = flag;
    }
}
