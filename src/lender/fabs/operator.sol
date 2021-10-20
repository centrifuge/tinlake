// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import { Operator } from "./../operator.sol";

interface OperatorFabLike {
    function newOperator(address) external returns (address);
}

contract OperatorFab {
    function newOperator(address tranche) public returns (address) {
        Operator operator = new Operator(tranche);
        operator.rely(msg.sender);
        operator.deny(address(this));
        return address(operator);
    }
}
