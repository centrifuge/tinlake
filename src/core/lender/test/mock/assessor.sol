pragma solidity >=0.4.24;

import "ds-math/math.sol";

contract AssessorMock is DSMath {

    uint256 constant ONE = 10 ** 27;

    address public senior;
    address public junior;

    mapping (bytes32 => uint) calls;
    mapping (bytes32 => uint) returnValues;


    function setReturn(bytes32 name, uint returnValue) public {
        returnValues[name] = returnValue;
    }

    function funcBody(bytes32 name) internal returns (uint) {
        calls[name]++;
        return returnValues[name];
    }

    function calcTokenPrice () public returns (uint) {
        uint tokenSupply = funcBody("tokenSupply");
        uint assetValue = funcBody("assetValue");
        if (tokenSupply == 0) {
            return ONE;
        }
        if (assetValue == 0) {
            revert("tranche is bankrupt");
        }
        return rdiv(assetValue, tokenSupply);
    }

    function calcAssetValue(address tranche) public returns (uint) {
        uint trancheReserve;
        if (tranche == junior) {
            trancheReserve = returnValues["jBalance"];
        }
        trancheReserve = returnValues["sBalance"];
        uint poolValue = returnValues["pileDebt"];
        if (tranche == junior) {
            return calcJuniorAssetValue(poolValue, trancheReserve, seniorDebt());
        }
        return calcSeniorAssetValue(poolValue, trancheReserve, seniorDebt(), juniorReserve());
    }

    // Tranche.assets (Junior) = (Pool.value + Tranche.reserve - Senior.debt) > 0 && (Pool.value - Tranche.reserve - Senior.debt) || 0
    function calcJuniorAssetValue(uint poolValue, uint trancheReserve, uint seniorDebt) internal returns (uint) {
        int assetValue = int(poolValue + trancheReserve - seniorDebt);
        return (assetValue > 0) ? uint(assetValue) : 0;
    }
    // Tranche.assets (Senior) = (Tranche.debt < (Pool.value + Junior.reserve)) && (Senior.debt + Tranche.reserve) || (Pool.value + Junior.reserve + Tranche.reserve)
    function calcSeniorAssetValue(uint poolValue, uint trancheReserve, uint trancheDebt, uint juniorReserve) internal returns (uint) {
        return ((poolValue + juniorReserve) >= trancheDebt) ? (trancheDebt + trancheReserve) : (poolValue + juniorReserve + trancheReserve);
    }
    function juniorReserve() internal returns (uint) {
        return funcBody("juniorReserve");
    }
    function seniorDebt() internal returns (uint) {
        return funcBody("seniorDebt");
    }
}