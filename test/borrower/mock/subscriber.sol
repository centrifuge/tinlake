// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";

contract SubscriberMock is Mock {
    function borrowEvent(uint256 loan, uint256 amount) public {
        values_uint["borrowEvent"] = loan;
        values_uint["borrowEvent_amount"] = amount;
        call("borrowEvent");
    }

    function repayEvent(uint256 loan, uint256 amount) public {
        values_uint["repayEvent"] = loan;
        values_uint["repayEvent_amount"] = amount;
        call("repayEvent");
    }

    function lockEvent(uint256 loan) public {
        values_uint["lockEvent"] = loan;
        call("lockEvent");
    }

    function unlockEvent(uint256 loan) public {
        values_uint["unlockEvent"] = loan;
        call("unlockEvent");
    }
}
