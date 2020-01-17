pragma solidity >=0.5.12;

import "./mock.sol";

contract AssessorMock is Mock {
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