pragma solidity >=0.5.3;

import "../../../test/mock/mock.sol";

contract DistributorMock is Mock {

    function balance() public {
        calls["balance"]++;

    }
}
