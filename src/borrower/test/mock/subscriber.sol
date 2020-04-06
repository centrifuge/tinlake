pragma solidity >=0.5.15 <0.6.0;
import "../../../test/mock/mock.sol";

contract SubscriberMock is Mock {
    function borrowEvent(uint loan) public {
        values_uint["borrowEvent"]=loan;
        call("borrowEvent");
    }

    function unlockEvent(uint loan) public {
        values_uint["unlockEvent"]=loan;
        call("unlockEvent");
    }
}
