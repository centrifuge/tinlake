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